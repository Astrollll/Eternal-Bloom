extends RefCounted
class_name DashVFX

static func create_wind_line_texture() -> Texture2D:
	# Build a small streak texture that can be reused for dash motion.
	var image: Image = Image.create(28, 5, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for x in range(28):
		var t := float(x) / 27.0
		var alpha := lerpf(0.96, 0.04, t)
		var edge_alpha := alpha * 0.45
		image.set_pixel(x, 2, Color(0.86, 0.95, 1.0, alpha))
		image.set_pixel(x, 1, Color(0.72, 0.92, 1.0, edge_alpha))
		image.set_pixel(x, 3, Color(0.72, 0.92, 1.0, edge_alpha))
	return ImageTexture.create_from_image(image)

static func spawn_afterimage(
	owner: Node,
	root: Node,
	world_position: Vector2,
	z_index: int,
	base_tex: Texture2D,
	base_scale: Vector2,
	skin_tex: Texture2D,
	skin_scale: Vector2,
	skin_offset: Vector2,
	alpha: float,
	fade_time: float,
	dash_direction: Vector2 = Vector2.ZERO
) -> void:
	# Duplicate the current character visuals, then fade the copy out behind the dash.
	if root == null:
		return

	var ghost: Node2D = Node2D.new()
	ghost.name = "DashAfterimage"
	ghost.global_position = world_position
	ghost.z_index = z_index
	ghost.modulate = Color(0.7, 0.85, 1.0, alpha * 0.92)
	root.add_child(ghost)

	if base_tex != null:
		var base_ghost: Sprite2D = Sprite2D.new()
		base_ghost.texture = base_tex
		base_ghost.centered = true
		base_ghost.scale = base_scale * Vector2(1.07, 1.07)
		base_ghost.modulate = Color(1.0, 1.0, 1.0, 0.92)
		ghost.add_child(base_ghost)

	if skin_tex != null:
		var skin_ghost: Sprite2D = Sprite2D.new()
		skin_ghost.texture = skin_tex
		skin_ghost.centered = true
		skin_ghost.scale = skin_scale * Vector2(1.07, 1.07)
		skin_ghost.position = skin_offset
		skin_ghost.modulate = Color(1.0, 1.0, 1.0, 0.92)
		ghost.add_child(skin_ghost)

	var tween: Tween = owner.create_tween()
	var drift_dir: Vector2 = dash_direction.normalized() if dash_direction != Vector2.ZERO else Vector2.ZERO
	if drift_dir != Vector2.ZERO:
		tween.tween_property(ghost, "position", ghost.position - drift_dir * 8.0, max(0.05, fade_time * 0.55))
		tween.parallel().tween_property(ghost, "scale", Vector2(0.92, 0.92), max(0.05, fade_time * 0.55))
	tween.tween_property(ghost, "modulate:a", 0.0, max(0.07, fade_time * 1.18))
	tween.tween_callback(ghost.queue_free)

static func update_wind_effect(
	wind_effect: GPUParticles2D,
	dash_direction: Vector2,
	current_frame_tex: Texture2D
) -> void:
	# Reorient the wind particles so they trail in the opposite direction of travel.
	if wind_effect == null:
		return

	var dir: Vector2 = dash_direction.normalized() if dash_direction != Vector2.ZERO else Vector2.RIGHT
	var offset_dist := 14.0
	if current_frame_tex != null:
		offset_dist = current_frame_tex.get_height() * 0.32

	wind_effect.position = - dir * offset_dist
	wind_effect.rotation = dir.angle()
	wind_effect.emitting = true

	var material: ParticleProcessMaterial = wind_effect.process_material as ParticleProcessMaterial
	if material != null:
		material.direction = Vector3(-dir.x, -dir.y, 0.0)
