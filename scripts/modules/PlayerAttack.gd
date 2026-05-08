extends RefCounted
class_name PlayerAttack

const SlashImpactScene: PackedScene = preload("res://scenes/SlashImpact.tscn")
const ImpactBurstScene: PackedScene = preload("res://scenes/ImpactBurst.tscn")
const CameraShakeScene: PackedScene = preload("res://scenes/CameraShake.tscn")
const ProjectileScene: PackedScene = preload("res://scenes/Projectile.tscn")
const HIT_SFX_PATH: String = "res://assets/sfx/hit.wav"
const CAMERA_SHAKE_MIN_INTERVAL_MSEC: int = 45

static var _cached_hit_sfx: AudioStream = null
static var _did_try_load_hit_sfx: bool = false
static var _last_camera_shake_msec: int = -1000
static var _low_spec_mode: bool = false

static func set_low_spec_mode(enabled: bool) -> void:
	# Shared toggle used by both player and enemy combat paths.
	_low_spec_mode = enabled

static func apply_hit_stop(owner: Node, duration: float = 0.045, slow_scale: float = 0.045) -> void:
	# Briefly slow the game when an attack connects, then restore time automatically.
	if owner == null:
		return
	var tree: SceneTree = owner.get_tree()
	if tree == null:
		return

	var clamped_scale: float = clampf(slow_scale, 0.01, 1.0)
	Engine.time_scale = clamped_scale

	# Ignore time scale so restoration always happens on time.
	var timer: SceneTreeTimer = tree.create_timer(max(0.005, duration), true, false, true)
	timer.timeout.connect(func() -> void:
		Engine.time_scale = 1.0
	, CONNECT_ONE_SHOT)

static func apply_melee_hit(
	owner: CharacterBody2D,
	facing_right: bool,
	attack_range: float,
	attack_half_size: Vector2,
	attack_collision_mask: int,
	impact_fade_time: float
) -> void:
	# Sweep a hit box in front of the player, spawn impacts, and apply damage to everything caught in the arc.
	if owner == null or owner.get_world_2d() == null:
		return

	var direction := facing_direction(facing_right)
	var query_shape := RectangleShape2D.new()
	# Extend the melee box slightly beyond the configured range so the swing feels less rigid.
	var melee_length := attack_range + 8.0
	query_shape.size = Vector2(melee_length, attack_half_size.y * 2.2)

	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = query_shape
	# Center the shape between the player and the max range.
	params.transform = Transform2D(0.0, owner.global_position + direction * (melee_length * 0.5))
	params.collision_mask = attack_collision_mask
	params.collide_with_bodies = true
	params.collide_with_areas = true
	params.exclude = [owner.get_rid()]

	var hits := owner.get_world_2d().direct_space_state.intersect_shape(params, 12)
	if hits.is_empty():
		return

	# Briefly slow time only when an attack actually connects.
	apply_hit_stop(owner)

	var root := owner.get_tree().current_scene
	for hit in hits:
		var collider: Object = hit.get("collider")
		var hit_pos := owner.global_position + direction * attack_range

		# Prefer the exact intersection point when available for accurate impact placement
		if hit.has("position"):
			hit_pos = hit.get("position")
		elif collider is Node2D:
			hit_pos = (collider as Node2D).global_position

		spawn_slash_impact(owner, root, hit_pos, direction, impact_fade_time, collider)
		_apply_damage_callback(collider, direction)
		# brief flash on hit targets to make impacts more visible
		flash_node_on_hit(collider, 0.08)

static func spawn_enemy_melee_slash(owner: Node2D, target: Node2D, direction: Vector2, fade_time: float = 0.17) -> void:
	# Create a smaller enemy melee slash anchored near the target for close-range enemy attacks.
	if owner == null or target == null:
		return
	var root := owner.get_tree().current_scene
	if root == null:
		return

	var dir := direction.normalized() if direction != Vector2.ZERO else (target.global_position - owner.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	var hit_pos := target.global_position - dir * 4.0
	spawn_slash_impact(owner, root, hit_pos, dir, fade_time, target)

static func facing_direction(facing_right: bool) -> Vector2:
	# Convert a facing flag into a world-space horizontal direction.
	return Vector2.RIGHT if facing_right else Vector2.LEFT

static func camera_shake(root: Node, strength: float = 4.0, duration: float = 0.12) -> void:
	# Try to find an active Camera2D in the current viewport and apply a small offset shake.
	# Skip camera shake entirely in low-spec mode
	if _low_spec_mode:
		return
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_camera_shake_msec < CAMERA_SHAKE_MIN_INTERVAL_MSEC:
		return
	_last_camera_shake_msec = now_msec

	var cam: Camera2D = null
	if root != null and root.get_viewport() != null:
		cam = root.get_viewport().get_camera_2d()
	if cam == null:
		return

	var orig := cam.offset
	var tw := cam.create_tween()
	# random small offset then return to original
	var rx := randf() * 2.0 - 1.0
	var ry := randf() * 2.0 - 1.0
	tw.tween_property(cam, "offset", orig + Vector2(rx * strength, ry * strength), duration * 0.4)
	tw.tween_property(cam, "offset", orig, duration * 0.6)

const PLAYER_BURST_SHOTS: int = 3
const PLAYER_BURST_INTERVAL: float = 0.06

static func shoot_projectile(owner: Node2D, direction: Vector2, mask: int) -> void:
	# Fire a rapid burst of player shots toward the nearest enemy.
	_spawn_projectile_burst(owner, direction, mask, false, PLAYER_BURST_SHOTS, PLAYER_BURST_INTERVAL)

static func shoot_enemy_projectile(owner: Node2D, direction: Vector2, mask: int) -> void:
	# Fire an enemy-style projectile that uses the same projectile scene with a different behavior profile.
	spawn_projectile(owner, direction, mask, true)

static func _spawn_projectile_burst(owner: Node2D, direction: Vector2, mask: int, enemy_style: bool, shots: int, interval: float) -> void:
	# Spawn one projectile immediately, then queue the remaining shots with a short delay.
	if owner == null or shots <= 0:
		return

	spawn_projectile(owner, direction, mask, enemy_style)
	if owner.has_method("on_weapon_round_fired"):
		owner.call("on_weapon_round_fired", 0, shots, direction)
	if shots == 1 or owner.get_tree() == null:
		return

	var tree := owner.get_tree()
	for shot_index in range(1, shots):
		var delay := interval * float(shot_index)
		var timer := tree.create_timer(delay)
		timer.timeout.connect(func() -> void:
			if owner == null or not is_instance_valid(owner):
				return
			spawn_projectile(owner, direction, mask, enemy_style)
			if owner.has_method("on_weapon_round_fired"):
				owner.call("on_weapon_round_fired", shot_index, shots, direction)
		, CONNECT_ONE_SHOT)

static func spawn_projectile(owner: Node2D, direction: Vector2, mask: int, enemy_style: bool) -> void:
	# Instantiate the projectile, aim it, configure its style, and wire its hit callback.
	if owner == null or ProjectileScene == null:
		return
	
	var bullet_node = ProjectileScene.instantiate()
	if not bullet_node:
		return
	var bullet = bullet_node as Area2D
	if bullet == null:
		return
	if _low_spec_mode and bullet.has_method("set_low_spec_mode"):
		bullet.call("set_low_spec_mode", true)

	var target := _find_player_target(owner) if enemy_style else _find_nearest_enemy(owner)
	var final_dir := direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	if target != null:
		final_dir = (target.global_position - owner.global_position).normalized()
		if final_dir == Vector2.ZERO:
			final_dir = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
		
	owner.get_tree().current_scene.add_child(bullet)
	var spawn_origin := _projectile_spawn_origin(owner, enemy_style)
	var muzzle_offset := _projectile_spawn_forward_offset(owner, final_dir)
	bullet.global_position = spawn_origin + muzzle_offset
	bullet.collision_mask = mask
	bullet.velocity = final_dir * (920.0 if enemy_style else 700.0)
	bullet.speed = 920.0 if enemy_style else 700.0
	bullet.homing_strength = 0.0
	bullet.source = owner
	bullet.target = target if not enemy_style else null
	if bullet.has_method("set_projectile_style"):
		bullet.call("set_projectile_style", "enemy" if enemy_style else "player")
	bullet.callback = func(hit_target: Object) -> void:
		if hit_target == null:
			return
		if not (hit_target is Node):
			return
		var hit_node := hit_target as Node
		if enemy_style:
			if hit_node.name != "Player" and not hit_node.is_in_group("player"):
				return
		else:
			if not hit_node.is_in_group("enemies"):
				return
		_apply_damage_callback(hit_target, final_dir)
	
	# Optional: Small camera shake on shot for "kick"
	if not _low_spec_mode:
		camera_shake(owner.get_tree().current_scene, 2.0, 0.08)

static func _projectile_spawn_origin(owner: Node2D, enemy_style: bool) -> Vector2:
	# Spawn from the weapon sprite position if the owner has one (player with held gun).
	if owner == null:
		return Vector2.ZERO
	
	# Check if owner has a weapon sprite (gun held by player)
	var weapon_sprite := owner.get_node_or_null("GunSprite") as Sprite2D
	if weapon_sprite != null and weapon_sprite.visible:
		return weapon_sprite.global_position
	
	# Fallback: Spawn from the character's visual center, nudged downward so shots read closer to hand/sword height.
	var sprite_node := owner.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite_node != null:
		var visual_scale: float = maxf(absf(sprite_node.global_scale.x), absf(sprite_node.global_scale.y))
		var y_offset: float = (2.0 if enemy_style else 5.0) * maxf(visual_scale, 1.0)
		return sprite_node.global_position + Vector2(0.0, y_offset)
	return owner.global_position

static func _projectile_spawn_forward_offset(owner: Node2D, direction: Vector2) -> Vector2:
	# Push spawn point to the front of the shooter so the projectile and trail do not overlap the body.
	if direction == Vector2.ZERO:
		return Vector2.ZERO
	var dir := direction.normalized()
	var sprite_node := owner.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite_node == null:
		return dir * 12.0

	var half_frame: float = 12.0
	if sprite_node.sprite_frames != null and sprite_node.sprite_frames.has_animation(sprite_node.animation):
		var tex := sprite_node.sprite_frames.get_frame_texture(sprite_node.animation, sprite_node.frame)
		if tex != null:
			half_frame = max(tex.get_width(), tex.get_height()) * 0.5

	var visual_scale: float = maxf(absf(sprite_node.global_scale.x), absf(sprite_node.global_scale.y))
	var front_distance: float = half_frame * maxf(visual_scale, 1.0) + 6.0
	return dir * front_distance

static func _get_hit_sfx() -> AudioStream:
	# Resolve hit SFX once and reuse it to avoid per-impact resource checks/loads.
	if _did_try_load_hit_sfx:
		return _cached_hit_sfx
	_did_try_load_hit_sfx = true
	if ResourceLoader.exists(HIT_SFX_PATH):
		_cached_hit_sfx = load(HIT_SFX_PATH) as AudioStream
	return _cached_hit_sfx

static func _find_nearest_enemy(owner: Node2D) -> Node2D:
	# Search the enemy group and return the closest valid target to the owner.
	if owner == null or owner.get_tree() == null:
		return null
	var nearest: Node2D = null
	var min_dist := INF
	for e in owner.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if not (e is Node2D):
			continue
		var node := e as Node2D
		var d := owner.global_position.distance_to(node.global_position)
		if d < min_dist:
			min_dist = d
			nearest = node
	return nearest

static func _find_player_target(owner: Node2D) -> Node2D:
	# Resolve the player node from the current scene so enemy shots can track the hero.
	if owner == null or owner.get_tree() == null:
		return null
	var scene := owner.get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("Player") as Node2D

static func _apply_damage_callback(collider: Object, direction: Vector2) -> void:
	# Call whichever damage entry point the collider supports so combat stays decoupled.
	if collider == null:
		return
	if collider.has_method("on_hit_by_player"):
		collider.call("on_hit_by_player", 20, direction)
		return
	if collider.has_method("take_damage"):
		collider.call("take_damage", 20, direction)

static func flash_node_on_hit(collider: Object, duration: float = 0.08, flash_color: Color = Color(1, 1, 1, 1)) -> void:
	# Briefly tint CanvasItem-derived nodes to provide immediate hit feedback.
	# Skip hit flashes in low-spec mode to save tweens
	if _low_spec_mode or collider == null:
		return
	if collider is CanvasItem:
		var ci := collider as CanvasItem
		var orig := ci.modulate
		var tw := ci.create_tween()
		# quick bright flash then return to original color
		tw.tween_property(ci, "modulate", flash_color, duration * 0.35)
		tw.tween_property(ci, "modulate", orig, duration * 0.65)
		return
	# If collider has a custom flash method, prefer calling that instead
	if collider.has_method("flash_on_hit"):
		collider.call("flash_on_hit", duration)

static func spawn_slash_impact(
	owner: Node,
	root: Node,
	world_position: Vector2,
	direction: Vector2,
	fade_time: float,
	collider: Object = null
) -> void:
	# Spawn the slash visual, optionally play a sound, and apply camera shake for the hit.
	if owner == null or root == null:
		return

	if SlashImpactScene == null:
		return

	var effect := SlashImpactScene.instantiate() as Node2D
	if effect == null:
		return

	effect.global_position = world_position
	if collider is Node2D:
		effect.global_position = (collider as Node2D).global_position

	# If the collider looks like an enemy/object taking damage, emphasize the effect
	if collider != null and collider.has_method("take_damage"):
		# Slightly emphasized slash on damageable targets, keeping a clean style.
		var main_slash := effect.get_node_or_null("MainSlash") as Line2D
		var glow_slash := effect.get_node_or_null("GlowSlash") as Line2D
		if main_slash != null:
			main_slash.width = max(main_slash.width, 4.2)
			main_slash.default_color = Color(1.0, 1.0, 1.0, 0.98)
		if glow_slash != null:
			glow_slash.width = max(glow_slash.width, 3.4)
			glow_slash.default_color = Color(0.7, 0.9, 1.0, 0.58)
	# Keep slash in front of slashed objects so it never appears hidden behind them.
	effect.z_as_relative = false
	effect.z_index = 200
	root.add_child(effect)
	if effect.has_method("setup"):
		effect.call("setup", direction, fade_time)

	# Play optional hit sound if available
	var hit_sfx := _get_hit_sfx()
	if hit_sfx != null:
		var ap := AudioStreamPlayer2D.new()
		ap.stream = hit_sfx
		ap.global_position = effect.global_position
		root.add_child(ap)
		ap.play()

	# Camera shake for tactile feedback (use CameraShake manager if present)
	var shake_strength := 4.0
	if collider != null and collider.has_method("take_damage"):
		shake_strength = 8.0
	if _low_spec_mode:
		shake_strength *= 0.6
	# Try to find or create a CameraShake manager under the scene root
	var cam_node := root.get_node_or_null("CameraShake")
	if cam_node == null and CameraShakeScene != null:
		cam_node = CameraShakeScene.instantiate()
		cam_node.name = "CameraShake"
		root.add_child(cam_node)
	if cam_node != null and cam_node.has_method("shake"):
		cam_node.call("shake", shake_strength, 0.12)

	# Spawn an editable ImpactBurst if available
	if ImpactBurstScene != null:
		var burst := ImpactBurstScene.instantiate() as Node2D
		if burst != null:
			if _low_spec_mode and burst.has_method("set"):
				burst.set("count", 6)
				burst.set("duration", 0.16)
			burst.global_position = effect.global_position
			root.add_child(burst)
	else:
		# fallback to code-built burst
		if collider != null and collider.has_method("take_damage"):
			spawn_impact_burst(root, effect.global_position, 8 if _low_spec_mode else 16, Color(1.0, 0.75, 0.4, 1.0))
		else:
			spawn_impact_burst(root, effect.global_position, 5 if _low_spec_mode else 8, Color(0.6, 0.9, 1.0, 0.9))

static func spawn_impact_burst(root: Node, position: Vector2, count: int = 8, color: Color = Color(1, 1, 1, 1)) -> void:
	if root == null:
		return

	var burst := Node2D.new()
	burst.global_position = position
	root.add_child(burst)

	for i in range(count):
		var line := Line2D.new()
		line.width = 2.5
		line.default_color = color
		# short radial line; we'll scale it out with a tween
		line.points = PackedVector2Array([Vector2(-2, 0), Vector2(10, 0)])
		line.rotation = randf() * TAU
		burst.add_child(line)

	# Animate the burst: extend and fade
	var tw := burst.create_tween()
	tw.set_parallel(true)
	for child in burst.get_children():
		if child is Line2D:
			var l := child as Line2D
			var final_alpha := 0.0
			tw.tween_property(l, "width", l.width * 0.2, 0.18)
			tw.tween_property(l, "default_color:a", final_alpha, 0.22)
	tw.chain().tween_interval(0.22)
	tw.tween_callback(Callable(burst, "queue_free"))
