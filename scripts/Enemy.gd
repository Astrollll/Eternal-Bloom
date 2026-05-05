extends CharacterBody2D
class_name Enemy

@export var move_speed: float = 145.0
@export var chase_range: float = 260.0
@export var attack_range: float = 34.0
@export var ranged_attack_range: float = 190.0
@export var preferred_ranged_distance: float = 128.0
@export var retreat_distance: float = 68.0
@export var strafe_speed: float = 72.0
@export var turn_speed: float = 760.0
@export var far_approach_speed: float = 0.55
@export var accel: float = 1600.0
@export var avoidance_distance: float = 22.0
@export var avoidance_strength: float = 0.7
@export var knockback_force: float = 400.0
@export var knockback_stun_time: float = 0.12
@export var attack_cooldown: float = 0.8
@export var attack_damage: int = 10
@export var max_hp: int = 180
@export var hp_bar_offset: Vector2 = Vector2(0, -34)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

const WALK_IDLE_TEX: Texture2D = preload("res://assets/Tiny Wonder Forest 1.0/characters/main character old/walk and idle.png")
const ATTACK_TEX: Texture2D = preload("res://assets/Tiny Wonder Forest 1.0/characters/main character old/attack and die.png")
const PlayerAttackModule = preload("res://scripts/modules/PlayerAttack.gd")

var player: CharacterBody2D
var facing_right: bool = false
var is_attacking: bool = false
var attack_cooldown_left: float = 0.0
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
	if facing_lock_time_left > 0.0:
		return
		
	facing_right = right


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 1000.0 * delta)
	knockback_stun_left = max(0.0, knockback_stun_left - delta)
	# Facing lock timer: prevent transient flips while being knocked
	facing_lock_time_left = max(0.0, facing_lock_time_left - delta)
	if facing_lock_time_left > 0.0:
		# enforce locked facing while active
		facing_right = locked_facing_right
	if knockback_stun_left > 0.0:
		velocity = knockback_velocity
		# Interrupt any attack if stunned
		if is_attacking:
			is_attacking = false
		_play_idle()
		move_and_slide()
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

	if dist > chase_range:
		far_boost = far_approach_speed
		strafe_timer = 0.0

	if dist <= attack_range + 6.0 and attack_cooldown_left <= 0.0:
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


	if strafe_timer <= 0.0 and dist <= ranged_attack_range and dist > attack_range:
		strafe_timer = randf_range(0.55, 1.15)
		strafe_dir = - strafe_dir if randf() > 0.5 else strafe_dir

	var desired_velocity := (move_dir * move_speed * far_boost) + (lateral * strafe_speed * far_boost) + knockback_velocity

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

	# Apply acceleration-based steering for smoother turns
	velocity = velocity.move_toward(desired_velocity, accel * delta)
	
	# Extract the intended movement vector (ignoring knockback) to determine facing.
	# This prevents the enemy from visually flipping backwards when hit.
	var visual_velocity := velocity - knockback_velocity
	
	# Choose animation direction based on actual intent movement when available.
	if visual_velocity.length() < 6.0:
		if dir != Vector2.ZERO:
			_set_facing(dir.x >= 0.0)
		_play_idle()
	else:
		var anim_dir := visual_velocity.normalized()
		_update_walk_anim(anim_dir)
		
	move_and_slide()

func _start_attack(to_player: Vector2) -> void:
	is_attacking = true
	attack_cooldown_left = attack_cooldown
	if abs(to_player.x) >= abs(to_player.y):
		_set_facing(to_player.x >= 0.0)
	_play_anim("attack_right")
	sprite.flip_h = locked_facing_right if facing_lock_time_left > 0.0 else facing_right

	if to_player.length() <= attack_range + 8.0:
		if player != null and is_instance_valid(player):
			PlayerAttackModule.spawn_enemy_melee_slash(self , player, to_player, 0.18)
			if player.has_method("on_hit_by_enemy"):
				player.call("on_hit_by_enemy", attack_damage, to_player.normalized())
			elif player.has_method("take_damage"):
				player.call("take_damage", attack_damage, to_player.normalized())


func _start_ranged_attack(to_player: Vector2) -> void:
	attack_cooldown_left = attack_cooldown + 0.1
	if abs(to_player.x) >= abs(to_player.y):
		_set_facing(to_player.x >= 0.0)
	_play_anim("attack_right")
	sprite.flip_h = locked_facing_right if facing_lock_time_left > 0.0 else facing_right

	if player != null and is_instance_valid(player):
		var shoot_dir := to_player.normalized() if to_player != Vector2.ZERO else (Vector2.RIGHT if facing_right else Vector2.LEFT)
		PlayerAttackModule.shoot_enemy_projectile(self , shoot_dir, 1)

func _on_animation_finished() -> void:
	if is_dead and String(sprite.animation).begins_with("die"):
		_start_death_fade()
		return

	if String(sprite.animation).begins_with("attack"):
		is_attacking = false
		_play_idle()

func _update_walk_anim(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		_play_idle()
		return

	if abs(dir.x) >= abs(dir.y):
		_set_facing(dir.x > 0.0)
		_play_anim("walk_right")
		sprite.flip_h = locked_facing_right if facing_lock_time_left > 0.0 else facing_right
	else:
		if dir.y > 0.0:
			_play_anim("walk_down")
		else:
			_play_anim("walk_up")

func _play_idle() -> void:
	_play_anim("idle_right")
	sprite.flip_h = locked_facing_right if facing_lock_time_left > 0.0 else facing_right

func _play_anim(anim: StringName) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)

func on_hit_by_player(amount: int, direction: Vector2 = Vector2.ZERO) -> void:
	take_damage(amount, direction)

func take_damage(amount: int, direction: Vector2 = Vector2.ZERO) -> void:
	if is_dead or amount <= 0:
		return
	current_hp = max(0, current_hp - amount)
	_update_hp_bar()

	# Apply knockback to the enemy
	if direction != Vector2.ZERO:
		knockback_velocity = direction.normalized() * knockback_force
		knockback_stun_left = knockback_stun_time
		# Lock facing briefly to avoid transient flip from the instantaneous push
		locked_facing_right = facing_right
		facing_lock_time_left = knockback_stun_time + 0.06

	# Ensure enemy never remains partially transparent from overlapping tweens.
	modulate = Color(1.0, 1.0, 1.0, 1.0)

	var hit_tw: Tween = create_tween()
	hit_tw.tween_property(self , "modulate", Color(1.28, 0.72, 0.72, 1.0), 0.05)
	hit_tw.tween_property(self , "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)

	if current_hp <= 0:
		_die()

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	death_fade_started = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	_play_anim("die_right")
	sprite.flip_h = facing_right
	sprite.frame = 0

func _start_death_fade() -> void:
	if death_fade_started:
		return
	death_fade_started = true
	var fade_tw: Tween = create_tween()
	fade_tw.tween_interval(0.15)
	fade_tw.tween_property(self , "modulate:a", 0.0, 0.35)
	fade_tw.tween_callback(queue_free)

func _setup_hp_bar() -> void:
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
	if hp_bar_fill == null:
		return
	var pct: float = clampf(float(current_hp) / float(max(1, max_hp)), 0.0, 1.0)
	var half_w: float = 17.0
	hp_bar_fill.points = PackedVector2Array([Vector2(-half_w, 0), Vector2(-half_w + (half_w * 2.0 * pct), 0)])

func _build_sprite_frames() -> void:
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
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, speed)
	frames.set_animation_loop(anim_name, loop)
	for cell in cells:
		var frame: AtlasTexture = AtlasTexture.new()
		frame.atlas = atlas
		frame.region = Rect2(cell.x * 24, cell.y * 24, 24, 24)
		frames.add_frame(anim_name, frame)
