extends Node2D
class_name SlashImpact

@export var fade_time: float = 0.15
@onready var main_slash: Line2D = $MainSlash
@onready var glow_slash: Line2D = $GlowSlash

var _impact_direction: Vector2 = Vector2.RIGHT

func setup(direction: Vector2, impact_fade_time: float) -> void:
	_impact_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	rotation = _impact_direction.angle()
	fade_time = impact_fade_time
	start()

func start() -> void:
	scale = Vector2.ONE
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	skew = 0.0

	var angle_jitter: float = randf_range(-0.06, 0.06)
	rotation += angle_jitter

	# Minimalist slash: thin clean stroke with a subtle soft trail.
	main_slash.width = max(main_slash.width, 2.6)
	glow_slash.width = max(glow_slash.width, 1.4)
	main_slash.default_color = Color(1.0, 1.0, 1.0, 0.94)
	glow_slash.default_color = Color(0.75, 0.9, 1.0, 0.42)

	# Use additive blending for the glow to make it pop on top of backgrounds
	var glow_mat: CanvasItemMaterial = CanvasItemMaterial.new()
	# Use the Godot 4 enum name for additive blend mode
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_slash.material = glow_mat

	# Smear-then-settle timing adds punch without visual clutter.
	var smear_scale: Vector2 = Vector2(1.36, 0.9)
	var settle_scale: Vector2 = Vector2(1.06, 1.02)
	var smear_time: float = max(0.018, fade_time * 0.22)
	var settle_time: float = max(0.02, fade_time * 0.23)

	var tw: Tween = create_tween()
	tw.tween_property(self , "scale", smear_scale, smear_time)
	tw.parallel().tween_property(self , "skew", 0.16, smear_time)
	tw.parallel().tween_property(self , "global_position", global_position + _impact_direction * 7.0, smear_time)
	tw.tween_property(self , "scale", settle_scale, settle_time)
	tw.parallel().tween_property(self , "skew", 0.0, settle_time)
	tw.parallel().tween_property(self , "global_position", global_position + _impact_direction * 10.0, settle_time)
	tw.parallel().tween_property(self , "modulate:a", 0.0, max(0.06, fade_time * 0.6))

	var glow_tw: Tween = create_tween()
	glow_tw.tween_property(glow_slash, "width", max(1.0, glow_slash.width * 1.8), smear_time)
	glow_tw.tween_property(glow_slash, "width", max(0.4, glow_slash.width * 0.45), max(0.06, fade_time * 0.6))

	tw.tween_callback(queue_free)
