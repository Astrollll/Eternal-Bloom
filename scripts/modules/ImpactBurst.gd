extends Node2D
class_name ImpactBurst

@export var count: int = 8
@export var color: Color = Color(1, 1, 1, 1)
@export var line_width: float = 2.5
@export var inner_len: float = -2.0
@export var outer_len: float = 10.0
@export var duration: float = 0.22

func _ready() -> void:
	# Build radial short lines and animate them.
	for i in range(count):
		var line: Line2D = Line2D.new()
		line.width = line_width * randf_range(0.82, 1.2)
		line.default_color = color
		var outer: float = outer_len * randf_range(0.85, 1.35)
		line.points = PackedVector2Array([Vector2(inner_len, 0), Vector2(outer, 0)])
		line.rotation = randf() * TAU
		add_child(line)

	# Quick pop before fade makes the hit read better.
	scale = Vector2(0.72, 0.72)
	var root_tw: Tween = create_tween()
	root_tw.tween_property(self , "scale", Vector2(1.08, 1.08), duration * 0.28)
	root_tw.tween_property(self , "scale", Vector2(1.0, 1.0), duration * 0.18)

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	for child in get_children():
		if child is Line2D:
			var l := child as Line2D
			# Shrink and fade in parallel for all rays.
			tw.tween_property(l, "width", max(0.2, l.width * 0.08), duration * 0.62)
			tw.tween_property(l, "default_color:a", 0.0, duration)

	tw.tween_callback(self.queue_free)
