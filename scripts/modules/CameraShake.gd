extends Node
class_name CameraShake

@export var default_strength: float = 4.0

func shake(strength: float = 4.0, duration: float = 0.12) -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return

	var base_strength: float = max(0.01, strength)
	var total_duration: float = max(0.02, duration)
	var orig: Vector2 = cam.offset
	var tw: Tween = create_tween()

	# Use short decaying pulses for a crisper impact feel.
	var steps: int = 4
	for i in range(steps):
		var t: float = float(i) / float(max(1, steps - 1))
		var decay: float = 1.0 - t
		var rx: float = randf() * 2.0 - 1.0
		var ry: float = randf() * 2.0 - 1.0
		tw.tween_property(
			cam,
			"offset",
			orig + Vector2(rx, ry) * (base_strength * decay),
			total_duration / float(steps + 1)
		)

	tw.tween_property(cam, "offset", orig, total_duration / float(steps + 1))
