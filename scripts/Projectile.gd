extends Area2D

var velocity: Vector2 = Vector2.ZERO
var damage: int = 15
var callback: Callable
var source: Node = null
var target: Node2D = null
@export var speed: float = 700.0
@export var homing_strength: float = 10.0
@export var trail_interval: float = 0.04
@export var trail_lifetime: float = 0.16
@export var approach_radius: float = 86.0
@export var ribbon_interval_scale: float = 1.0
@export var low_spec_mode: bool = false
@onready var bullet_visual: Polygon2D = get_node_or_null("BulletVisual") as Polygon2D
@onready var glow_visual: Polygon2D = get_node_or_null("GlowVisual") as Polygon2D
@onready var trail_particles: GPUParticles2D = get_node_or_null("TrailParticles") as GPUParticles2D
@onready var enemy_bullet_line: Line2D = get_node_or_null("EnemyBulletLine") as Line2D
@onready var enemy_bullet_glow: Line2D = get_node_or_null("EnemyBulletGlow") as Line2D

var _bullet_base_polygon: PackedVector2Array = PackedVector2Array()
var _glow_base_polygon: PackedVector2Array = PackedVector2Array()
var _enemy_line_base_points: PackedVector2Array = PackedVector2Array()
var _enemy_glow_base_points: PackedVector2Array = PackedVector2Array()
var _life_time: float = 0.0
var _ribbon_time_left: float = 0.0
@warning_ignore("unused_private_class_variable")
var _approach_fx_played: bool = false
var _trail_texture: Texture2D
var _projectile_style: StringName = &"player"
var _ribbon_points: PackedVector2Array = PackedVector2Array()
var _ribbon_glow_material: CanvasItemMaterial

func _ready() -> void:
	# Set up collision, visuals, particles, and the initial motion state.
	# The projectile is also given a safety timer so it cannot live forever if it misses.
	add_to_group("projectiles")
	# connect signal to explicit Callable to avoid inference/connect issues
	self.body_entered.connect(Callable(self , "_on_body_entered"))
	_build_visuals()
	_setup_trail_particles()
	_start_visual_motion()
	_setup_ribbon_cache()
	_apply_low_spec_tuning()
	
	# Ensure the projectile faces its travel direction
	if velocity != Vector2.ZERO:
		rotation = velocity.angle()
	
	# Auto-destruct after 1.5 seconds to prevent memory leaks
	var t := get_tree().create_timer(1.5)
	t.timeout.connect(Callable(self , "queue_free"))

func _physics_process(delta: float) -> void:
	# Update lifetime and steer toward a target when homing is enabled.
	_life_time += delta

	if target != null and is_instance_valid(target):
		# Move velocity toward the target direction instead of snapping instantly.
		var desired := (target.global_position - global_position).normalized() * speed
		if desired != Vector2.ZERO:
			velocity = velocity.move_toward(desired, homing_strength * speed * delta)

	# Drive visuals from the projectile's age and how close it is to its target.
	var proximity := _target_proximity()
	_animate_bullet_shape(_life_time, proximity)
	_emit_trail(proximity)
	if not low_spec_mode:
		_emit_ribbon(delta, proximity)

	# Keep the projectile and its trail aligned to the current travel direction.
	if velocity != Vector2.ZERO:
		rotation = velocity.angle()

	# Move the projectile after all steering and visual updates are applied.
	global_position += velocity * delta

func _setup_ribbon_cache() -> void:
	# Cache immutable ribbon geometry/material to avoid per-spawn allocations.
	_ribbon_points = PackedVector2Array([
		Vector2(-18, 0),
		Vector2(-10, -4),
		Vector2(-2, -2),
		Vector2(6, 2),
		Vector2(14, 4),
		Vector2(20, 0)
	])
	_ribbon_glow_material = CanvasItemMaterial.new()
	_ribbon_glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

func set_low_spec_mode(enabled: bool) -> void:
	low_spec_mode = enabled
	_apply_low_spec_tuning()

func _apply_low_spec_tuning() -> void:
	# Reduce expensive projectile visuals when low-spec mode is enabled.
	ribbon_interval_scale = 1.9 if low_spec_mode else 1.0
	if trail_particles != null:
		trail_particles.amount = 34 if low_spec_mode else 64
		trail_particles.lifetime = 0.24 if low_spec_mode else 0.34

func _start_visual_motion() -> void:
	# Give each visible layer an additive material so it reads like a bright orb or slash.
	_apply_style_visuals()
	if bullet_visual != null:
		var bullet_mat := CanvasItemMaterial.new()
		bullet_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		bullet_visual.material = bullet_mat

	if glow_visual != null:
		var glow_mat := CanvasItemMaterial.new()
		glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow_visual.material = glow_mat
	if enemy_bullet_line != null:
		var line_mat := CanvasItemMaterial.new()
		line_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		enemy_bullet_line.material = line_mat
	if enemy_bullet_glow != null:
		var line_glow_mat := CanvasItemMaterial.new()
		line_glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		enemy_bullet_glow.material = line_glow_mat

	# Orb-like bullet motion: slight pulse instead of a static slash.
	scale = Vector2(0.72, 0.72)
	var tw: Tween = create_tween()
	tw.tween_property(self , "scale", Vector2(1.05, 1.05), 0.08)
	tw.tween_property(self , "scale", Vector2(0.96, 0.96), 0.09)
	tw.tween_property(self , "scale", Vector2(1.0, 1.0), 0.06)

	if bullet_visual != null:
		bullet_visual.scale = Vector2.ONE
	if glow_visual != null:
		glow_visual.scale = Vector2.ONE

func _build_visuals() -> void:
	# Build the base meshes and line points once, then reuse them for animation.
	_bullet_base_polygon = _make_circle_polygon(8, 7.0)
	_glow_base_polygon = _make_circle_polygon(10, 11.5)
	_enemy_line_base_points = PackedVector2Array([Vector2(-14, 0), Vector2(-8, 0), Vector2(8, 0), Vector2(14, 0)])
	_enemy_glow_base_points = PackedVector2Array([Vector2(-18, 0), Vector2(-10, 0), Vector2(10, 0), Vector2(18, 0)])

	if bullet_visual != null:
		bullet_visual.polygon = _bullet_base_polygon
		bullet_visual.color = Color(0.28, 1.0, 0.24, 0.98)
		bullet_visual.scale = Vector2.ONE
	if glow_visual != null:
		glow_visual.polygon = _glow_base_polygon
		glow_visual.color = Color(0.64, 1.0, 0.5, 0.22)
		glow_visual.scale = Vector2.ONE
	if enemy_bullet_line != null:
		enemy_bullet_line.points = PackedVector2Array([Vector2(-10, 0), Vector2(-5, 0), Vector2(5, 0), Vector2(10, 0)])
		enemy_bullet_line.width = 2.6
		enemy_bullet_line.default_color = Color(1.0, 0.28, 0.26, 0.92)
	if enemy_bullet_glow != null:
		enemy_bullet_glow.points = PackedVector2Array([Vector2(-14, 0), Vector2(-7, 0), Vector2(7, 0), Vector2(14, 0)])
		enemy_bullet_glow.width = 5.2
		enemy_bullet_glow.default_color = Color(1.0, 0.46, 0.34, 0.22)

func set_projectile_style(style: StringName) -> void:
	# Swap between player and enemy presentation without changing movement or damage.
	_projectile_style = style
	_apply_style_visuals()
	_apply_trail_style()

func _apply_style_visuals() -> void:
	# Only one visual set should be visible at a time.
	var enemy_style := _projectile_style == &"enemy"
	if bullet_visual != null:
		bullet_visual.visible = not enemy_style
	if glow_visual != null:
		glow_visual.visible = not enemy_style
	if enemy_bullet_line != null:
		enemy_bullet_line.visible = enemy_style
	if enemy_bullet_glow != null:
		enemy_bullet_glow.visible = enemy_style

func _setup_trail_particles() -> void:
	# Create a trail particle node on demand so the scene can omit it safely.
	if trail_particles == null:
		trail_particles = GPUParticles2D.new()
		trail_particles.name = "TrailParticles"
		add_child(trail_particles)

	# Configure a short-lived streak that reacts to style and proximity.
	trail_particles.emitting = true
	trail_particles.amount = 64
	trail_particles.lifetime = 0.34
	trail_particles.one_shot = false
	trail_particles.local_coords = true
	trail_particles.z_index = -1
	trail_particles.z_as_relative = false
	trail_particles.speed_scale = 1.35
	trail_particles.texture = _get_trail_texture()

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(-1.0, 0.0, 0.0)
	mat.spread = 14.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 68.0
	mat.initial_velocity_max = 148.0
	mat.angular_velocity_min = -10.0
	mat.angular_velocity_max = 10.0
	mat.scale_min = 0.34
	mat.scale_max = 0.78
	mat.hue_variation_min = -0.03
	mat.hue_variation_max = 0.03
	mat.color = Color(1.0, 1.0, 1.0, 1.0)
	trail_particles.process_material = mat
	_apply_trail_style()

func _get_trail_texture() -> Texture2D:
	# Cache a small radial texture so particle setup does not rebuild it every time.
	if _trail_texture != null:
		return _trail_texture
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(12):
		for y in range(12):
			var d := Vector2(x - 5.5, y - 5.5).length()
			var a := clampf(1.0 - (d / 5.5), 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_trail_texture = ImageTexture.create_from_image(img)
	return _trail_texture

func _apply_trail_style() -> void:
	# Tint the trail differently for player and enemy shots.
	var enemy_style := _projectile_style == &"enemy"
	if trail_particles != null:
		var mat := trail_particles.process_material as ParticleProcessMaterial
		if mat != null:
			mat.color = Color(1.0, 0.34, 0.26, 1.0) if enemy_style else Color(0.46, 1.0, 0.32, 1.0)
		trail_particles.modulate = Color(1.0, 0.24, 0.18, 1.0) if enemy_style else Color(0.52, 1.0, 0.34, 1.0)

func _make_circle_polygon(points_count: int, radius: float) -> PackedVector2Array:
	# Generate evenly spaced points around a circle for the bullet body and glow.
	var poly := PackedVector2Array()
	for i in range(points_count):
		var angle := TAU * float(i) / float(points_count)
		poly.append(Vector2(cos(angle), sin(angle)) * radius)
	return poly


func _target_proximity() -> float:
	if target == null or not is_instance_valid(target):
		return 0.0
	var d := global_position.distance_to(target.global_position)
	return clampf(1.0 - (d / max(1.0, approach_radius)), 0.0, 1.0)


func _animate_bullet_shape(t: float, proximity: float) -> void:
	# Use a rhythmic pulse and target proximity to make the projectile feel alive.
	var pulse := sin(t * 20.0) * 0.04 + cos(t * 13.0) * 0.03
	var approach_boost := 1.0 + proximity * 0.38
	var scale_value := 1.0 + pulse
	var glow_scale := 1.0 + pulse * 1.45 + proximity * 0.18
	var enemy_style := _projectile_style == &"enemy"

	if bullet_visual != null and not enemy_style:
		bullet_visual.scale = Vector2(scale_value, scale_value) * approach_boost
		bullet_visual.rotation = sin(t * 12.0) * 0.08
		bullet_visual.color = Color(0.28, 1.0, 0.24, lerpf(0.82, 1.0, proximity))

	if glow_visual != null and not enemy_style:
		glow_visual.scale = Vector2(glow_scale, glow_scale) * approach_boost
		glow_visual.rotation = - sin(t * 10.0) * 0.06
		glow_visual.color = Color(0.62, 1.0, 0.48, lerpf(0.14, 0.34, proximity))

	if enemy_bullet_line != null and enemy_style:
		enemy_bullet_line.scale = Vector2(0.82 + proximity * 0.22, 1.0)
		enemy_bullet_line.rotation = sin(t * 10.0) * 0.03
		enemy_bullet_line.width = lerpf(2.2, 3.2, proximity)
		enemy_bullet_line.default_color = Color(1.0, 0.2, 0.18, lerpf(0.9, 1.0, proximity))

	if enemy_bullet_glow != null and enemy_style:
		enemy_bullet_glow.scale = Vector2(0.9 + proximity * 0.25, 1.0)
		enemy_bullet_glow.rotation = - sin(t * 8.0) * 0.025
		enemy_bullet_glow.width = lerpf(4.6, 6.0, proximity)
		enemy_bullet_glow.default_color = Color(1.0, 0.42, 0.32, lerpf(0.14, 0.28, proximity))

	if trail_particles != null:
		trail_particles.amount_ratio = lerpf(0.82, 1.0, proximity)
		trail_particles.speed_scale = lerpf(1.05, 1.6, proximity)
		trail_particles.modulate = Color(1.0, 0.26, 0.22, lerpf(0.88, 1.0, proximity)) if enemy_style else Color(0.52, 1.0, 0.34, lerpf(0.82, 1.0, proximity))

func _emit_trail(proximity: float) -> void:
	# Keep the particle trail active and stronger when the projectile is close to its target.
	if trail_particles == null:
		return
	trail_particles.emitting = true
	trail_particles.amount_ratio = lerpf(0.82, 1.0, proximity)
	trail_particles.speed_scale = lerpf(1.1, 1.7, proximity)
	if _projectile_style == &"enemy":
		trail_particles.modulate = Color(1.0, 0.26, 0.22, lerpf(0.92, 1.0, proximity))

func _emit_ribbon(delta: float, proximity: float) -> void:
	# Spawn a short-lived line ribbon at a controlled interval so the projectile leaves a visible streak.
	_ribbon_time_left -= delta
	if _ribbon_time_left > 0.0:
		return
	var scaled_interval: float = (trail_interval * 0.75 - proximity * 0.004) * maxf(0.5, ribbon_interval_scale)
	_ribbon_time_left = maxf(0.022, scaled_interval)

	var root := get_tree().current_scene
	if root == null:
		return

	var ribbon := Node2D.new()
	ribbon.global_position = global_position
	ribbon.global_rotation = global_rotation
	ribbon.z_as_relative = false
	ribbon.z_index = z_index - 1
	root.add_child(ribbon)

	var ribbon_line := Line2D.new()
	ribbon_line.width = lerpf(6.0, 10.0, proximity)
	ribbon_line.default_color = Color(1.0, 0.28, 0.22, lerpf(0.28, 0.6, proximity)) if _projectile_style == &"enemy" else Color(0.22, 1.0, 0.16, lerpf(0.28, 0.6, proximity))
	ribbon_line.points = _ribbon_points
	ribbon_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ribbon_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	ribbon_line.joint_mode = Line2D.LINE_JOINT_ROUND
	ribbon.add_child(ribbon_line)

	var ribbon_glow := Line2D.new()
	ribbon_glow.width = ribbon_line.width * 1.8
	ribbon_glow.default_color = Color(1.0, 0.48, 0.34, lerpf(0.12, 0.28, proximity)) if _projectile_style == &"enemy" else Color(0.56, 1.0, 0.42, lerpf(0.12, 0.28, proximity))
	ribbon_glow.points = _ribbon_points
	ribbon_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ribbon_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	ribbon_glow.joint_mode = Line2D.LINE_JOINT_ROUND
	ribbon_glow.material = _ribbon_glow_material
	ribbon.add_child(ribbon_glow)

	var tw := ribbon.create_tween()
	tw.tween_property(ribbon, "scale", Vector2(1.08, 1.08), trail_lifetime)
	tw.parallel().tween_property(ribbon, "modulate:a", 0.0, trail_lifetime)
	tw.tween_callback(Callable(ribbon, "queue_free"))

func _play_approach_burst() -> void:
	# Add a small scale bump when the projectile enters its close-range visual phase.
	var burst_tw := create_tween()
	burst_tw.tween_property(self , "scale", Vector2(1.16, 1.16), 0.035)
	burst_tw.tween_property(self , "scale", Vector2(1.0, 1.0), 0.075)
	if bullet_visual != null:
		var bullet_tw := create_tween()
		bullet_tw.tween_property(bullet_visual, "modulate:a", 1.0, 0.03)
		bullet_tw.tween_property(bullet_visual, "modulate:a", 0.88, 0.08)
	if glow_visual != null:
		var glow_tw := create_tween()
		glow_tw.tween_property(glow_visual, "modulate:a", 0.42, 0.03)
		glow_tw.tween_property(glow_visual, "modulate:a", 0.26, 0.08)

func _on_body_entered(body: Node) -> void:
	# Ignore the shooter, limit player projectiles to enemies, then hand the hit to the callback.
	if body == source:
		return

	# Player projectiles should only resolve on enemies.
	if source != null and source.name == "Player":
		if not body.is_in_group("enemies"):
			return

	# If we hit a damageable target, trigger the callback
	if callback.is_valid():
		callback.call(body)
	
	# Create a small impact effect before disappearing
	if trail_particles != null:
		trail_particles.emitting = false
	queue_free()
