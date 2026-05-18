extends RefCounted
class_name DashVFX

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
