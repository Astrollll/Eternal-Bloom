extends Node2D
class_name SlashImpact

@export var fade_time: float = 0.15
@onready var main_slash: Line2D = $MainSlash
@onready var glow_slash: Line2D = $GlowSlash
@onready var echo_slash: Line2D = get_node_or_null("EchoSlash") as Line2D
@onready var core_slash: Line2D = get_node_or_null("CoreSlash") as Line2D

var _impact_direction: Vector2 = Vector2.RIGHT

func setup(direction: Vector2, impact_fade_time: float) -> void:
	# Store the slash direction, rotate the effect, and kick off the animation.
	_impact_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	rotation = _impact_direction.angle()
	fade_time = impact_fade_time
	start()

func start() -> void:
	# Initialize the slash in a visible state before the timed smear and fade begin.
	scale = Vector2.ONE
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	skew = 0.0

	var angle_jitter: float = randf_range(-0.06, 0.06)
	rotation += angle_jitter

	# Layered slash: core blade, light trail, and warm echo for contrast on all tiles.
	main_slash.width = max(main_slash.width, 3.2)
	glow_slash.width = max(glow_slash.width, 2.0)
	main_slash.default_color = Color(1.0, 1.0, 1.0, 0.98)
	glow_slash.default_color = Color(0.75, 0.9, 1.0, 0.56)
	if echo_slash != null:
		echo_slash.width = max(echo_slash.width, 2.0)
		echo_slash.default_color = Color(1.0, 0.86, 0.58, 0.52)
		echo_slash.rotation = randf_range(-0.14, 0.14)
	if core_slash != null:
		core_slash.width = max(core_slash.width, 1.1)
		core_slash.default_color = Color(1.0, 1.0, 1.0, 0.95)

	# Use additive blending for the glow to make it pop on top of backgrounds
	var glow_mat: CanvasItemMaterial = CanvasItemMaterial.new()
	# Use the Godot 4 enum name for additive blend mode
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_slash.material = glow_mat
	if echo_slash != null:
		var echo_mat := CanvasItemMaterial.new()
		echo_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		echo_slash.material = echo_mat

	# Smear-then-settle timing adds punch without visual clutter.
	var smear_scale: Vector2 = Vector2(1.62, 0.86)
	var settle_scale: Vector2 = Vector2(1.12, 1.03)
	var smear_time: float = max(0.02, fade_time * 0.24)
	var settle_time: float = max(0.02, fade_time * 0.24)
	var fade_out_time: float = max(0.07, fade_time * 0.62)
	var start_pos := global_position

	var tw: Tween = create_tween()
	tw.tween_property(self , "scale", smear_scale, smear_time)
	tw.parallel().tween_property(self , "skew", 0.18, smear_time)
	tw.parallel().tween_property(self , "global_position", start_pos + _impact_direction * 8.0, smear_time)
	tw.tween_property(self , "scale", settle_scale, settle_time)
	tw.parallel().tween_property(self , "skew", 0.0, settle_time)
	tw.parallel().tween_property(self , "global_position", start_pos + _impact_direction * 12.0, settle_time)
	tw.parallel().tween_property(self , "modulate:a", 0.0, fade_out_time)

	var glow_tw: Tween = create_tween()
	glow_tw.tween_property(glow_slash, "width", max(1.0, glow_slash.width * 1.9), smear_time)
	glow_tw.tween_property(glow_slash, "width", max(0.4, glow_slash.width * 0.38), fade_out_time)

	if echo_slash != null:
		var echo_tw: Tween = create_tween()
		echo_tw.tween_property(echo_slash, "position", Vector2(-3.0, 1.5), smear_time)
		echo_tw.parallel().tween_property(echo_slash, "width", max(0.7, echo_slash.width * 1.35), smear_time)
		echo_tw.tween_property(echo_slash, "position", Vector2(4.0, -1.5), settle_time + fade_out_time)
		echo_tw.parallel().tween_property(echo_slash, "default_color:a", 0.0, settle_time + fade_out_time)

	if core_slash != null:
		var core_tw: Tween = create_tween()
		core_tw.tween_property(core_slash, "width", max(0.6, core_slash.width * 1.25), smear_time)
		core_tw.tween_property(core_slash, "width", 0.25, fade_out_time)
		core_tw.parallel().tween_property(core_slash, "default_color:a", 0.0, fade_out_time)

	tw.tween_callback(queue_free)
