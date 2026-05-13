extends CanvasLayer
class_name GameOverUI

var bg: ColorRect
var card: PanelContainer
var title_label: Label
var subtitle_label: Label
var hint_label: Label
var restart_btn_shell: Control
var restart_btn: Button
var btn_tween: Tween
var intro_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	# Full-screen overlay to mute the paused game behind the dialog.
	bg = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03, 0.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Center the panel and keep the composition stable on different resolutions.
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	card = PanelContainer.new()
	card.custom_minimum_size = Vector2(680, 360)
	card.pivot_offset = Vector2(340, 180)
	card.scale = Vector2(0.94, 0.94)
	card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	center.add_child(card)
	card.add_theme_stylebox_override("panel", _create_card_style())

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	card.add_child(margin)

	var content = VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	var accent = ColorRect.new()
	accent.custom_minimum_size = Vector2(0, 6)
	accent.color = Color(0.95, 0.25, 0.28, 1.0)
	content.add_child(accent)

	title_label = Label.new()
	title_label.text = "GAME OVER"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.32, 0.34))
	title_label.add_theme_color_override("font_shadow_color", Color(0.08, 0.0, 0.0, 0.95))
	title_label.add_theme_constant_override("shadow_offset_x", 5)
	title_label.add_theme_constant_override("shadow_offset_y", 5)
	title_label.custom_minimum_size = Vector2(0, 92)
	content.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "The bloom has faded. You can try again and push deeper next run."
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 20)
	subtitle_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98, 0.9))
	subtitle_label.custom_minimum_size = Vector2(0, 72)
	content.add_child(subtitle_label)

	# Restart button with stronger contrast, depth, and clear focus state.
	restart_btn_shell = Control.new()
	restart_btn_shell.custom_minimum_size = Vector2(300, 76)
	restart_btn_shell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart_btn_shell.pivot_offset = restart_btn_shell.custom_minimum_size * 0.5
	content.add_child(restart_btn_shell)

	restart_btn = Button.new()
	restart_btn.text = "TRY AGAIN"
	restart_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	restart_btn.focus_mode = Control.FOCUS_ALL
	restart_btn.add_theme_font_size_override("font_size", 30)
	restart_btn.add_theme_font_size_override("outline_size", 2)
	restart_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	restart_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	restart_btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	restart_btn.add_theme_stylebox_override("normal", _create_button_style(Color(0.18, 0.44, 0.86), Color(0.58, 0.82, 1.0), 8.0, 1.0))
	restart_btn.add_theme_stylebox_override("hover", _create_button_style(Color(0.23, 0.56, 0.98), Color(0.8, 0.96, 1.0), 12.0, 1.04))
	restart_btn.add_theme_stylebox_override("pressed", _create_button_style(Color(0.1, 0.3, 0.7), Color(0.34, 0.62, 0.92), 4.0, 0.98))
	restart_btn.add_theme_stylebox_override("focus", _create_button_style(Color(0.23, 0.56, 0.98), Color(1.0, 1.0, 1.0), 12.0, 1.04))
	restart_btn_shell.add_child(restart_btn)

	hint_label = Label.new()
	hint_label.text = "Press Enter or click to restart"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.94, 0.75))
	hint_label.custom_minimum_size = Vector2(0, 28)
	content.add_child(hint_label)

	restart_btn.pressed.connect(_on_restart_pressed)
	restart_btn.mouse_entered.connect(func(): _play_button_scale_animation(1.04))
	restart_btn.mouse_exited.connect(func(): _play_button_scale_animation(1.0))
	restart_btn_shell.resized.connect(_center_restart_button_pivot)
	restart_btn.call_deferred("grab_focus")
	call_deferred("_center_restart_button_pivot")

	_animate_in()

func _animate_in() -> void:
	# Fade the overlay in quickly, then pause the game underneath.
	if intro_tween != null and intro_tween.is_valid():
		intro_tween.kill()

	card.scale = Vector2(0.92, 0.92)
	intro_tween = create_tween()
	intro_tween.set_parallel(true)
	intro_tween.tween_property(bg, "color", Color(0.02, 0.02, 0.03, 0.84), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(card, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	intro_tween.tween_callback(func(): get_tree().paused = true)
	intro_tween.tween_interval(0.02)
	intro_tween.tween_callback(func(): restart_btn.grab_focus())

func _on_restart_pressed() -> void:
	# Give a little button feedback, then restart the scene cleanly.
	_button_press_feedback()
	await get_tree().create_timer(0.18).timeout
	get_tree().paused = false
	get_tree().reload_current_scene()

func _play_button_scale_animation(target_scale: float) -> void:
	if restart_btn == null:
		return
	if btn_tween != null and btn_tween.is_valid():
		btn_tween.kill()
	
	btn_tween = create_tween()
	btn_tween.set_trans(Tween.TRANS_QUART)
	btn_tween.set_ease(Tween.EASE_OUT)
	btn_tween.tween_property(restart_btn_shell, "scale", Vector2(target_scale, target_scale), 0.16)

func _center_restart_button_pivot() -> void:
	# Keep the scale origin centered so the button grows evenly on hover and press.
	if restart_btn_shell == null:
		return
	restart_btn_shell.pivot_offset = restart_btn_shell.size * 0.5

func _button_press_feedback() -> void:
	# Quick scale down and back up for click feedback.
	if restart_btn == null:
		return
	var tw = create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(restart_btn_shell, "scale", Vector2(0.96, 0.96), 0.08)
	tw.tween_property(restart_btn_shell, "scale", Vector2(1.0, 1.0), 0.12)

func _create_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.11, 0.97)
	style.border_color = Color(0.88, 0.22, 0.26, 0.9)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 24
	style.corner_radius_bottom_right = 24
	style.set_content_margin_all(18)
	style.shadow_size = 18
	style.shadow_color = Color(0, 0, 0, 0.55)
	return style

func _create_button_style(bg_color: Color, border_color: Color, shadow_size: float, _scale_hint: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.set_content_margin_all(14)
	style.shadow_size = int(shadow_size)
	style.shadow_color = Color(0, 0, 0, 0.5)
	return style
