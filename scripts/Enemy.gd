extends CharacterBody2D
class_name Enemy

@export var move_speed: float = 145.0
@export var chase_range: float = 260.0
@export var attack_range: float = 42.0
@export var ranged_attack_range: float = 190.0
@export var preferred_ranged_distance: float = 128.0
@export var retreat_distance: float = 68.0
@export var strafe_speed: float = 72.0
@export var turn_speed: float = 760.0
@export var far_approach_speed: float = 0.55
@export var accel: float = 1600.0
@export var movement_smoothing: float = 8.0
@export var arrival_slowdown_distance: float = 115.0
@export var nearby_facing_sync_distance: float = 240.0
@export var avoidance_distance: float = 22.0
@export var avoidance_strength: float = 0.7
@export var dash_speed: float = 820.0
@export var dash_duration: float = 0.14
@export var dash_cooldown: float = 0.55
@export var dash_afterimage_interval: float = 0.05
@export var dash_afterimage_fade_time: float = 0.12
@export var dash_afterimage_alpha: float = 0.3
@export var projectile_dodge_radius: float = 150.0
@export var projectile_dodge_trigger_distance: float = 84.0
@export var projectile_dodge_lookahead: float = 0.34
@export var knockback_force: float = 320.0
@export var knockback_stun_time: float = 0.08
@export var attack_cooldown: float = 0.3
@export_range(1, 6, 1) var ranged_burst_shots: int = 3
@export var ranged_burst_interval: float = 0.05
@export var attack_damage: int = 10
@export var max_hp: int = 180
@export var hp_bar_offset: Vector2 = Vector2(0, -34)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

const WALK_IDLE_TEX: Texture2D = preload("res://assets/Tiny Wonder Forest 1.0/characters/main character old/walk and idle.png")
const ATTACK_TEX: Texture2D = preload("res://assets/Tiny Wonder Forest 1.0/characters/main character old/attack and die.png")
const DashVFXModule = preload("res://scripts/modules/DashVFX.gd")
const PlayerAttackModule: Script = preload("res://scripts/modules/PlayerAttack.gd")

var player: CharacterBody2D
var facing_right: bool = false
var is_attacking: bool = false
var attack_cooldown_left: float = 0.0
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.LEFT
var dash_time_left: float = 0.0
var dash_cooldown_left: float = 0.0
var dash_speed_multiplier: float = 1.0
var dash_duration_multiplier: float = 1.0
var dash_afterimage_time_left: float = 0.0
var current_hp: int = 0
var is_dead: bool = false

var hp_bar_bg: Line2D
var hp_bar_fill: Line2D
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_stun_left: float = 0.0
var facing_lock_time_left: float = 0.0
var locked_facing_right: bool = false
var death_fade_started: bool = false
var strafe_dir: float = 1.0
var strafe_timer: float = 0.0

func _ready() -> void:
	# Register the enemy, build its animation frames, and cache the player reference.
	add_to_group("enemies")
	_build_sprite_frames()
	_setup_hp_bar()
	current_hp = max_hp
	_update_hp_bar()
	player = get_tree().current_scene.get_node_or_null("Player") as CharacterBody2D
	if player != null:
		add_collision_exception_with(player)
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("idle_left")

func _set_facing(right: bool) -> void:
	# Respect knockback-facing locks so hit reactions do not immediately flip the sprite.
	if facing_lock_time_left > 0.0:
		return
		
	facing_right = right

func _face_toward(direction: Vector2) -> void:
	# Use a world-space direction to decide which side the enemy should present.
	if _is_player_facing_sync_active():
		_apply_player_facing_sync()
		return
	if direction.x != 0.0:
		_set_facing(direction.x > 0.0)

func _play_facing_anim(left_anim: StringName, right_anim: StringName) -> void:
	# Pick the correct directional animation instead of flipping a single pose everywhere.
	# The sprite rows are authored mirrored to their names, so use the opposite row for true facing.
	_play_anim(left_anim if facing_right else right_anim)
	sprite.flip_h = false


func _physics_process(delta: float) -> void:
	# Run enemy AI, handle stun/knockback, and choose movement or attack based on distance.
	if is_dead:
		velocity = Vector2.ZERO
		return

	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 1000.0 * delta)
	knockback_stun_left = max(0.0, knockback_stun_left - delta)
	if dash_cooldown_left > 0.0:
		dash_cooldown_left = max(0.0, dash_cooldown_left - delta)
	# Facing lock timer: prevent transient flips while being knocked
	facing_lock_time_left = max(0.0, facing_lock_time_left - delta)
	if facing_lock_time_left > 0.0:
		# enforce locked facing while active
		facing_right = locked_facing_right
	if knockback_stun_left > 0.0:
		if is_dashing:
			_end_dash()
		velocity = knockback_velocity
		# Interrupt any attack if stunned
		if is_attacking:
			is_attacking = false
		_play_idle()
		move_and_slide()
		return

	if is_dashing:
		dash_time_left = max(0.0, dash_time_left - delta)
		velocity = dash_direction * dash_speed * dash_speed_multiplier + knockback_velocity
		move_and_slide()
		_spawn_dash_afterimage(delta)
		_update_walk_anim(dash_direction)
		if dash_time_left <= 0.0:
			_end_dash()
		return

	if attack_cooldown_left > 0.0:
		attack_cooldown_left = max(0.0, attack_cooldown_left - delta)
	strafe_timer -= delta

	if player == null or not is_instance_valid(player):
		player = get_tree().current_scene.get_node_or_null("Player") as CharacterBody2D
		if player != null:
			add_collision_exception_with(player)
		velocity = knockback_velocity
		move_and_slide()
		return

	if is_attacking:
		velocity = knockback_velocity
		move_and_slide()
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()
	var dir: Vector2 = to_player.normalized() if dist > 0.001 else Vector2.ZERO
	var lateral: Vector2 = Vector2(-dir.y, dir.x) * strafe_dir
	var far_boost: float = 1.0
	_sync_facing_with_player_if_near(dist)

	if _try_start_projectile_dodge():
		velocity = dash_direction * dash_speed * dash_speed_multiplier + knockback_velocity
		move_and_slide()
		_spawn_dash_afterimage(0.0)
		_update_walk_anim(dash_direction)
		return

	if dist > chase_range:
		far_boost = far_approach_speed
		strafe_timer = 0.0

	if dist <= attack_range + 12.0 and attack_cooldown_left <= 0.0:
		_start_attack(to_player)
		velocity = knockback_velocity
		move_and_slide()
		return

	if dist <= ranged_attack_range and attack_cooldown_left <= 0.0:
		_start_ranged_attack(to_player)

	var move_dir := Vector2.ZERO
	if dist < retreat_distance:
		move_dir = - dir * 1.25 + lateral * 0.18
	elif dist < preferred_ranged_distance:
		move_dir = lateral * 0.9 + dir * 0.2
	else:
		move_dir = dir * 0.95 + lateral * 0.16

	if move_dir != Vector2.ZERO:
		move_dir = move_dir.normalized()

	# Ease movement speed as the enemy settles into preferred ranged distance.
	var arrival_scale: float = 1.0
	if dist <= preferred_ranged_distance + arrival_slowdown_distance:
		arrival_scale = clampf((dist - retreat_distance) / maxf(1.0, preferred_ranged_distance + arrival_slowdown_distance - retreat_distance), 0.45, 1.0)


	if strafe_timer <= 0.0 and dist <= ranged_attack_range and dist > attack_range:
		strafe_timer = randf_range(0.55, 1.15)
		strafe_dir = - strafe_dir if randf() > 0.5 else strafe_dir

	var desired_velocity := (move_dir * move_speed * far_boost * arrival_scale) + (lateral * strafe_speed * far_boost * arrival_scale) + knockback_velocity

	# Simple obstacle avoidance: raycast forward and nudge away from normals
	var space := get_world_2d().direct_space_state
	var avoid_hit = null
	if move_dir != Vector2.ZERO:
		var exclude_arr := []
		exclude_arr.append(self.get_rid())
		if player != null:
			exclude_arr.append(player.get_rid())
		var params := PhysicsRayQueryParameters2D.new()
		params.from = global_position
		params.to = global_position + move_dir * avoidance_distance
		params.exclude = exclude_arr
		avoid_hit = space.intersect_ray(params)
	if avoid_hit != null and avoid_hit.has("position"):
		var n: Vector2 = avoid_hit.get("normal")
		desired_velocity += n * move_speed * avoidance_strength

	# Smooth abrupt intent changes so strafing/chasing reads more fluidly.
	var current_intent := velocity - knockback_velocity
	var desired_intent := desired_velocity - knockback_velocity
	var smooth_weight := clampf(movement_smoothing * delta, 0.0, 1.0)
	desired_velocity = current_intent.lerp(desired_intent, smooth_weight) + knockback_velocity

	# Apply acceleration-based steering for smoother turns
	var steering_rate: float = turn_speed if turn_speed > 0.0 else accel
	velocity = velocity.move_toward(desired_velocity, steering_rate * delta)
	
	# Extract the intended movement vector (ignoring knockback) to determine facing.
	# This prevents the enemy from visually flipping backwards when hit.
	var visual_velocity := velocity - knockback_velocity
	
	# Choose animation direction based on actual intent movement when available.
	if visual_velocity.length() < 6.0:
		if dir != Vector2.ZERO:
			_face_toward(dir)
		_play_idle()
	else:
		var anim_dir := visual_velocity.normalized()
		_update_walk_anim(anim_dir)
		
	move_and_slide()

func _sync_facing_with_player_if_near(distance_to_player: float) -> void:
	# When close to the player, mirror the player's horizontal facing for tighter visual readability.
	if distance_to_player <= nearby_facing_sync_distance:
		_apply_player_facing_sync()

func _is_player_facing_sync_active() -> bool:
	# Enable facing sync only when the player is valid and close enough.
	if player == null or not is_instance_valid(player):
		return false
	return global_position.distance_to(player.global_position) <= nearby_facing_sync_distance

func _apply_player_facing_sync() -> void:
	# Face toward the player when nearby so the enemy stays visually focused on the target.
	if player == null or not is_instance_valid(player):
		return
	var to_player := player.global_position - global_position
	if absf(to_player.x) > 0.001:
		_set_facing(to_player.x > 0.0)

func _start_attack(to_player: Vector2) -> void:
	# Trigger the close-range attack sequence and apply damage if the player is in range.
	is_attacking = true
	attack_cooldown_left = attack_cooldown
	if abs(to_player.x) >= abs(to_player.y):
		_face_toward(to_player)
	_play_facing_anim("attack_left", "attack_right")

	if to_player.length() <= attack_range + 12.0:
		if player != null and is_instance_valid(player):
			PlayerAttackModule.spawn_enemy_melee_slash(self , player, to_player, 0.18)
			if player.has_method("on_hit_by_enemy"):
				player.call("on_hit_by_enemy", attack_damage, to_player.normalized())
			elif player.has_method("take_damage"):
				player.call("take_damage", attack_damage, to_player.normalized())


func _start_ranged_attack(to_player: Vector2) -> void:
	# Fire a ranged projectile when the player sits inside the enemy's preferred combat band.
	attack_cooldown_left = attack_cooldown
	if abs(to_player.x) >= abs(to_player.y):
		_face_toward(to_player)
	_play_facing_anim("attack_left", "attack_right")

	if player != null and is_instance_valid(player):
		var shoot_dir := to_player.normalized() if to_player != Vector2.ZERO else (Vector2.RIGHT if facing_right else Vector2.LEFT)
		PlayerAttackModule.shoot_enemy_projectile(self , shoot_dir, 1, ranged_burst_shots, ranged_burst_interval)

func _on_animation_finished() -> void:
	# Reset the attack state when the animation completes, and start fading after death.
	if is_dead and String(sprite.animation).begins_with("die"):
		_start_death_fade()
		return

	if String(sprite.animation).begins_with("attack"):
		is_attacking = false
		_play_idle()

func _update_walk_anim(dir: Vector2) -> void:
	# Pick a walk animation that matches the dominant movement axis.
	if dir == Vector2.ZERO:
		_play_idle()
		return

	if _is_player_facing_sync_active():
		_apply_player_facing_sync()

	if abs(dir.x) >= abs(dir.y):
		_face_toward(dir)
		_play_facing_anim("walk_left", "walk_right")
	else:
		if dir.y > 0.0:
			_play_anim("walk_down")
			sprite.flip_h = facing_right
		else:
			_play_anim("walk_up")
			sprite.flip_h = not facing_right

func _play_idle() -> void:
	# Force the enemy into a stable idle animation while preserving the current facing.
	_play_facing_anim("idle_left", "idle_right")

func _play_anim(anim: StringName) -> void:
	# Only play animations that exist on the sprite frames resource.
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)

func on_hit_by_player(amount: int, direction: Vector2 = Vector2.ZERO) -> void:
	# Provide a unified callback so player attacks can damage enemies through one entry point.
	take_damage(amount, direction)

func take_damage(amount: int, direction: Vector2 = Vector2.ZERO) -> void:
	# Reduce HP, apply knockback, flash the enemy, and transition to death when HP reaches zero.
	if is_dead or amount <= 0:
		return
	current_hp = max(0, current_hp - amount)
	_update_hp_bar()

	# Apply knockback to the enemy
	if direction != Vector2.ZERO:
		knockback_velocity = direction.normalized() * knockback_force
		knockback_stun_left = knockback_stun_time
		# Keep the enemy oriented toward the player instead of flipping with the knockback impulse.
		_apply_player_facing_sync()
		_play_facing_anim("idle_left", "idle_right")

	# Ensure enemy never remains partially transparent from overlapping tweens.
	modulate = Color(1.0, 1.0, 1.0, 1.0)

	var hit_tw: Tween = create_tween()
	hit_tw.tween_property(self , "modulate", Color(1.28, 0.72, 0.72, 1.0), 0.05)
	hit_tw.tween_property(self , "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)

	if current_hp <= 0:
		_die()

func _can_start_dash() -> bool:
	# Allow a dodge dash only when the enemy is free to move and the dash is off cooldown.
	return not is_dead and not is_dashing and knockback_stun_left <= 0.0 and dash_cooldown_left <= 0.0

func _try_start_projectile_dodge() -> bool:
	# Scan incoming player projectiles and convert a close threat into a short dash.
	if not _can_start_dash() or player == null or not is_instance_valid(player):
		return false

	var threat := _find_projectile_threat()
	if threat == null:
		return false

	var away_dir := _build_projectile_dodge_direction(threat)
	if away_dir == Vector2.ZERO:
		var fallback := global_position - player.global_position
		away_dir = fallback.normalized() if fallback != Vector2.ZERO else (Vector2.RIGHT if facing_right else Vector2.LEFT)

	var homing_threat: bool = threat.get("target") == self
	_start_dash(away_dir, 1.25 if homing_threat else 1.0, 1.05 if homing_threat else 1.0)
	return true

func _build_projectile_dodge_direction(projectile: Node2D) -> Vector2:
	# Prefer a perpendicular step across the shot path, then add a little outward drift.
	if projectile == null:
		return Vector2.ZERO

	var projectile_velocity_variant: Variant = projectile.get("velocity")
	var projectile_velocity: Vector2 = projectile_velocity_variant if projectile_velocity_variant is Vector2 else Vector2.ZERO
	var offset := global_position - projectile.global_position

	if projectile_velocity == Vector2.ZERO:
		return offset.normalized() if offset != Vector2.ZERO else Vector2.ZERO

	var travel_dir := projectile_velocity.normalized()
	var side_dir := Vector2(-travel_dir.y, travel_dir.x)
	var side_sign := 1.0 if travel_dir.cross(offset) >= 0.0 else -1.0
	var dodge_dir := (side_dir * side_sign * 0.55) + (offset.normalized() * 0.12)
	if dodge_dir == Vector2.ZERO:
		return Vector2.ZERO
	return dodge_dir.normalized()

func _find_projectile_threat() -> Node2D:
	# Pick the closest player-fired projectile that is likely to pass through the enemy soon.
	var best_projectile: Node2D = null
	var best_score: float = INF
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		if not is_instance_valid(projectile):
			continue
		if not (projectile is Node2D):
			continue
		if not _is_player_projectile(projectile):
			continue

		var projectile_node := projectile as Node2D
		var offset := global_position - projectile_node.global_position
		var distance := offset.length()
		if distance > projectile_dodge_radius:
			continue
		if distance > projectile_dodge_trigger_distance:
			continue

		var projectile_velocity_variant: Variant = projectile.get("velocity")
		var projectile_velocity: Vector2 = projectile_velocity_variant if projectile_velocity_variant is Vector2 else Vector2.ZERO
		if projectile_velocity != Vector2.ZERO:
			var travel_dir := projectile_velocity.normalized()
			var approach := offset.dot(travel_dir)
			if approach < -6.0:
				continue
			var perp := absf(offset.cross(travel_dir))
			if perp > projectile_dodge_radius * 0.8:
				continue
			var time_to_pass := maxf(0.0, approach) / maxf(1.0, projectile_velocity.length())
			if time_to_pass > projectile_dodge_lookahead and distance > projectile_dodge_radius * 0.55:
				continue

		var score := distance
		if projectile.get("target") == self:
			score -= 60.0
		if score < best_score:
			best_score = score
			best_projectile = projectile_node

	return best_projectile

func _is_player_projectile(projectile: Object) -> bool:
	# Only dodge shots that belong to the player side.
	var shot_source: Variant = projectile.get("source")
	if shot_source == null:
		return false
	if shot_source == player:
		return true
	if shot_source is Node and (shot_source as Node).name == "Player":
		return true
	return shot_source is Node and (shot_source as Node).is_in_group("player")

func _start_dash(direction: Vector2, duration_scale: float = 1.0, speed_scale: float = 1.0) -> void:
	# Lock a dodge direction, interrupt attacks, and kick off the dash VFX cycle.
	if direction == Vector2.ZERO:
		return
	is_dashing = true
	is_attacking = false
	dash_direction = direction.normalized()
	dash_duration_multiplier = maxf(0.25, duration_scale)
	dash_speed_multiplier = maxf(0.25, speed_scale)
	dash_time_left = dash_duration * dash_duration_multiplier
	dash_cooldown_left = dash_cooldown
	dash_afterimage_time_left = 0.0
	if absf(dash_direction.x) >= absf(dash_direction.y):
		_face_toward(dash_direction)
	_spawn_dash_afterimage(0.0)

func _end_dash() -> void:
	# Return to the regular movement state once the dodge window closes.
	is_dashing = false
	dash_speed_multiplier = 1.0
	dash_duration_multiplier = 1.0
	velocity = Vector2.ZERO

func _spawn_dash_afterimage(delta: float) -> void:
	# Emit repeated ghost copies behind the dash so the enemy reads like the player does.
	dash_afterimage_time_left -= delta
	while dash_afterimage_time_left <= 0.0:
		_create_dash_afterimage()
		dash_afterimage_time_left += max(0.01, dash_afterimage_interval)

func _create_dash_afterimage() -> void:
	# Reuse the shared dash VFX helper with the enemy's current animation frame.
	var root: Node = get_tree().current_scene
	if root == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(sprite.animation):
		return

	var base_tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	DashVFXModule.spawn_afterimage(
		self ,
		root,
		global_position,
		sprite.z_index - 1,
		base_tex,
		sprite.scale,
		null,
		Vector2.ONE,
		Vector2.ZERO,
		dash_afterimage_alpha,
		dash_afterimage_fade_time,
		dash_direction
	)

func _die() -> void:
	# Stop movement and collision before the death animation finishes and fades away.
	if is_dead:
		return
	is_dead = true
	death_fade_started = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	_play_facing_anim("die_left", "die_right")
	sprite.frame = 0

func _start_death_fade() -> void:
	# Fade the corpse out after the death animation ends to keep the scene uncluttered.
	if death_fade_started:
		return
	death_fade_started = true
	var fade_tw: Tween = create_tween()
	fade_tw.tween_interval(0.15)
	fade_tw.tween_property(self , "modulate:a", 0.0, 0.35)
	fade_tw.tween_callback(queue_free)

func _setup_hp_bar() -> void:
	# Attach a compact HP bar above the enemy for quick combat feedback.
	hp_bar_bg = Line2D.new()
	hp_bar_bg.width = 5.0
	hp_bar_bg.default_color = Color(0.12, 0.12, 0.12, 0.82)
	hp_bar_bg.position = hp_bar_offset
	hp_bar_bg.points = PackedVector2Array([Vector2(-18, 0), Vector2(18, 0)])
	hp_bar_bg.z_index = 100
	add_child(hp_bar_bg)

	hp_bar_fill = Line2D.new()
	hp_bar_fill.width = 3.0
	hp_bar_fill.default_color = Color(0.96, 0.26, 0.26, 0.95)
	hp_bar_fill.position = hp_bar_offset
	hp_bar_fill.points = PackedVector2Array([Vector2(-17, 0), Vector2(17, 0)])
	hp_bar_fill.z_index = 101
	add_child(hp_bar_fill)

func _update_hp_bar() -> void:
	# Update the fill length to match the enemy's remaining health.
	if hp_bar_fill == null:
		return
	var pct: float = clampf(float(current_hp) / float(max(1, max_hp)), 0.0, 1.0)
	var half_w: float = 17.0
	hp_bar_fill.points = PackedVector2Array([Vector2(-half_w, 0), Vector2(-half_w + (half_w * 2.0 * pct), 0)])

func _build_sprite_frames() -> void:
	# Build a complete animation set from the atlas so the enemy can walk, attack, and die.
	if sprite == null:
		return
	var frames: SpriteFrames = SpriteFrames.new()
	_add_anim(frames, "idle_left", WALK_IDLE_TEX, [Vector2i(0, 0), Vector2i(1, 0)], 6.0, true)
	_add_anim(frames, "idle_right", WALK_IDLE_TEX, [Vector2i(2, 0), Vector2i(3, 0)], 6.0, true)
	_add_anim(frames, "walk_down", WALK_IDLE_TEX, [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)], 10.0, true)
	_add_anim(frames, "walk_up", WALK_IDLE_TEX, [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)], 10.0, true)
	_add_anim(frames, "walk_left", WALK_IDLE_TEX, [Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2)], 10.0, true)
	_add_anim(frames, "walk_right", WALK_IDLE_TEX, [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)], 10.0, true)
	_add_anim(frames, "attack_left", ATTACK_TEX, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)], 14.0, false)
	_add_anim(frames, "attack_right", ATTACK_TEX, [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)], 14.0, false)
	_add_anim(frames, "die_left", ATTACK_TEX, [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)], 8.0, false)
	_add_anim(frames, "die_right", ATTACK_TEX, [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)], 8.0, false)
	sprite.sprite_frames = frames

func _add_anim(frames: SpriteFrames, anim_name: StringName, atlas: Texture2D, cells: Array[Vector2i], speed: float, loop: bool) -> void:
	# Slice each requested cell into an atlas frame and append it to the target animation.
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, speed)
	frames.set_animation_loop(anim_name, loop)
	for cell in cells:
		var frame: AtlasTexture = AtlasTexture.new()
		frame.atlas = atlas
		frame.region = Rect2(cell.x * 24, cell.y * 24, 24, 24)
		frames.add_frame(anim_name, frame)
