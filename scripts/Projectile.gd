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
@onready var bullet_visual: Polygon2D = get_node_or_null("BulletVisual") as Polygon2D
@onready var glow_visual: Polygon2D = get_node_or_null("GlowVisual") as Polygon2D
@onready var trail_particles: GPUParticles2D = get_node_or_null("TrailParticles") as GPUParticles2D

var _bullet_base_polygon: PackedVector2Array = PackedVector2Array()
var _glow_base_polygon: PackedVector2Array = PackedVector2Array()
var _life_time: float = 0.0
var _trail_time_left: float = 0.0
var _ribbon_time_left: float = 0.0
var _approach_fx_played: bool = false
var _trail_texture: Texture2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build_visuals()
	_setup_trail_particles()
	_start_visual_motion()
	
	# Ensure the projectile faces its travel direction
	if velocity != Vector2.ZERO:
		rotation = velocity.angle()
	
	# Auto-destruct after 1.5 seconds to prevent memory leaks
	get_tree().create_timer(1.5).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	_life_time += delta

	if target != null and is_instance_valid(target):
		var desired := (target.global_position - global_position).normalized() * speed
		if desired != Vector2.ZERO:
			velocity = velocity.move_toward(desired, homing_strength * speed * delta)

	var proximity := _target_proximity()
	_animate_bullet_shape(_life_time, proximity)
	_emit_trail(delta, proximity)
	_emit_ribbon(delta, proximity)

	if proximity > 0.22 and not _approach_fx_played:
		_approach_fx_played = true
		_play_approach_burst()
	elif proximity <= 0.12:
		_approach_fx_played = false

	if velocity != Vector2.ZERO:
		rotation = velocity.angle()

	global_position += velocity * delta

func _start_visual_motion() -> void:
	if bullet_visual != null:
		var bullet_mat := CanvasItemMaterial.new()
		bullet_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		bullet_visual.material = bullet_mat

	if glow_visual != null:
		var glow_mat := CanvasItemMaterial.new()
		glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow_visual.material = glow_mat

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
	_bullet_base_polygon = _make_circle_polygon(8, 7.0)
	_glow_base_polygon = _make_circle_polygon(10, 11.5)

	if bullet_visual != null:
		bullet_visual.polygon = _bullet_base_polygon
		bullet_visual.color = Color(0.28, 1.0, 0.24, 0.98)
		bullet_visual.scale = Vector2.ONE
	if glow_visual != null:
		glow_visual.polygon = _glow_base_polygon
		glow_visual.color = Color(0.64, 1.0, 0.5, 0.22)
		glow_visual.scale = Vector2.ONE

func _setup_trail_particles() -> void:
	if trail_particles == null:
		trail_particles = GPUParticles2D.new()
		trail_particles.name = "TrailParticles"
		add_child(trail_particles)

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
	mat.color = Color(0.46, 1.0, 0.32, 1.0)
	trail_particles.process_material = mat

func _get_trail_texture() -> Texture2D:
	if _trail_texture != null:
		return _trail_texture
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(12):
		for y in range(12):
			var d := Vector2(x - 5.5, y - 5.5).length()
			var a := clampf(1.0 - (d / 5.5), 0.0, 1.0)
			img.set_pixel(x, y, Color(0.38, 1.0, 0.26, a))
	_trail_texture = ImageTexture.create_from_image(img)
	return _trail_texture

func _make_circle_polygon(points_count: int, radius: float) -> PackedVector2Array:
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
	var pulse := sin(t * 20.0) * 0.04 + cos(t * 13.0) * 0.03
	var approach_boost := 1.0 + proximity * 0.38
	var scale_value := 1.0 + pulse
	var glow_scale := 1.0 + pulse * 1.45 + proximity * 0.18

	if bullet_visual != null:
		bullet_visual.scale = Vector2(scale_value, scale_value) * approach_boost
		bullet_visual.rotation = sin(t * 12.0) * 0.08
		bullet_visual.color = Color(0.28, 1.0, 0.24, lerpf(0.82, 1.0, proximity))

	if glow_visual != null:
		glow_visual.scale = Vector2(glow_scale, glow_scale) * approach_boost
		glow_visual.rotation = - sin(t * 10.0) * 0.06
		glow_visual.color = Color(0.62, 1.0, 0.48, lerpf(0.14, 0.34, proximity))

	if trail_particles != null:
		trail_particles.amount_ratio = lerpf(0.82, 1.0, proximity)
		trail_particles.speed_scale = lerpf(1.05, 1.6, proximity)
		trail_particles.modulate = Color(0.52, 1.0, 0.34, lerpf(0.82, 1.0, proximity))

func _emit_trail(delta: float, proximity: float) -> void:
	if trail_particles == null:
		return
	trail_particles.emitting = true
	trail_particles.amount_ratio = lerpf(0.82, 1.0, proximity)
	trail_particles.speed_scale = lerpf(1.1, 1.7, proximity)

func _emit_ribbon(delta: float, proximity: float) -> void:
	_ribbon_time_left -= delta
	if _ribbon_time_left > 0.0:
		return
	_ribbon_time_left = max(0.01, trail_interval * 0.55 - proximity * 0.008)

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
	ribbon_line.default_color = Color(0.22, 1.0, 0.16, lerpf(0.28, 0.6, proximity))
	ribbon_line.points = PackedVector2Array([
		Vector2(-18, 0),
		Vector2(-10, -4),
		Vector2(-2, -2),
		Vector2(6, 2),
		Vector2(14, 4),
		Vector2(20, 0)
	])
	ribbon_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ribbon_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	ribbon_line.joint_mode = Line2D.LINE_JOINT_ROUND
	ribbon.add_child(ribbon_line)

	var ribbon_glow := Line2D.new()
	ribbon_glow.width = ribbon_line.width * 1.8
	ribbon_glow.default_color = Color(0.56, 1.0, 0.42, lerpf(0.12, 0.28, proximity))
	ribbon_glow.points = ribbon_line.points
	ribbon_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ribbon_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	ribbon_glow.joint_mode = Line2D.LINE_JOINT_ROUND
	var glow_mat := CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ribbon_glow.material = glow_mat
	ribbon.add_child(ribbon_glow)

	var tw := ribbon.create_tween()
	tw.tween_property(ribbon, "scale", Vector2(1.08, 1.08), trail_lifetime)
	tw.parallel().tween_property(ribbon, "modulate:a", 0.0, trail_lifetime)
	tw.tween_callback(Callable(ribbon, "queue_free"))

func _play_approach_burst() -> void:
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