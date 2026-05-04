extends RefCounted
class_name PlayerAttack

const SlashImpactScene: PackedScene = preload("res://scenes/SlashImpact.tscn")
const ImpactBurstScene: PackedScene = preload("res://scenes/ImpactBurst.tscn")
const CameraShakeScene: PackedScene = preload("res://scenes/CameraShake.tscn")
const ProjectileScene: PackedScene = preload("res://scenes/Projectile.tscn")

static func apply_hit_stop(owner: Node, duration: float = 0.045, slow_scale: float = 0.045) -> void:
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
	if owner == null or owner.get_world_2d() == null:
		return

	var direction := facing_direction(facing_right)
	var query_shape := RectangleShape2D.new()
	# Increase size to cover from the player center to the range to avoid "dead zones"
	query_shape.size = Vector2(attack_range, attack_half_size.y * 2.0)

	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = query_shape
	# Center the shape between the player and the max range
	params.transform = Transform2D(0.0, owner.global_position + direction * (attack_range * 0.5))
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

static func facing_direction(facing_right: bool) -> Vector2:
	return Vector2.RIGHT if facing_right else Vector2.LEFT

static func camera_shake(root: Node, strength: float = 4.0, duration: float = 0.12) -> void:
	# Try to find an active Camera2D in the current viewport and apply a small offset shake.
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

static func shoot_projectile(owner: Node2D, direction: Vector2, mask: int) -> void:
	if owner == null or ProjectileScene == null:
		return
	
	var bullet_node = ProjectileScene.instantiate()
	if not bullet_node:
		return
	var bullet = bullet_node as Area2D
		
	owner.get_tree().current_scene.add_child(bullet)
	bullet.global_position = owner.global_position + direction * 10.0
	bullet.collision_mask = mask
	bullet.velocity = direction * 700.0
	bullet.callback = func(target): _apply_damage_callback(target, direction)
	
	# Optional: Small camera shake on shot for "kick"
	camera_shake(owner.get_tree().current_scene, 2.0, 0.08)

static func _apply_damage_callback(collider: Object, direction: Vector2) -> void:
	if collider == null:
		return
	if collider.has_method("on_hit_by_player"):
		collider.call("on_hit_by_player", 20, direction)
		return
	if collider.has_method("take_damage"):
		collider.call("take_damage", 20, direction)

static func flash_node_on_hit(collider: Object, duration: float = 0.08, flash_color: Color = Color(1, 1, 1, 1)) -> void:
	# Briefly tint CanvasItem-derived nodes to provide immediate hit feedback.
	if collider == null:
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
			main_slash.width = max(main_slash.width, 3.2)
			main_slash.default_color = Color(1.0, 1.0, 1.0, 0.98)
		if glow_slash != null:
			glow_slash.width = max(glow_slash.width, 2.6)
			glow_slash.default_color = Color(0.7, 0.9, 1.0, 0.58)
	# Keep slash in front of slashed objects so it never appears hidden behind them.
	effect.z_as_relative = false
	effect.z_index = 200
	root.add_child(effect)
	if effect.has_method("setup"):
		effect.call("setup", direction, fade_time)

	# Play optional hit sound if available
	var sfx_path := "res://assets/sfx/hit.wav"
	if ResourceLoader.exists(sfx_path):
		var ap := AudioStreamPlayer2D.new()
		ap.stream = load(sfx_path)
		ap.global_position = effect.global_position
		root.add_child(ap)
		ap.play()

	# Camera shake for tactile feedback (use CameraShake manager if present)
	var shake_strength := 4.0
	if collider != null and collider.has_method("take_damage"):
		shake_strength = 8.0
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
			burst.global_position = effect.global_position
			root.add_child(burst)
	else:
		# fallback to code-built burst
		if collider != null and collider.has_method("take_damage"):
			spawn_impact_burst(root, effect.global_position, 12, Color(1.0, 0.75, 0.4, 1.0))
		else:
			spawn_impact_burst(root, effect.global_position, 8, Color(0.6, 0.9, 1.0, 0.9))

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
	for child in burst.get_children():
		if child is Line2D:
			var l := child as Line2D
			var final_alpha := 0.0
			tw.tween_property(l, "width", l.width * 0.2, 0.18)
			tw.tween_property(l, "default_color:a", final_alpha, 0.22)

	tw.tween_callback(Callable(burst, "queue_free"))
