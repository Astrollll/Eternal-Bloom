extends CanvasLayer
class_name GameOverUI

var bg: ColorRect
var vbox: VBoxContainer
var restart_btn: Button
var btn_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	
	# Semi-transparent dark background with vignette effect
	bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# CenterContainer ensures everything is perfectly centered on the screen
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 32)
	center.add_child(vbox)
	
	# Title with enhanced styling
	var title = Label.new()
	title.text = "G A M E   O V E R"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))
	title.add_theme_color_override("font_shadow_color", Color(0.1, 0, 0, 1.0))
	title.add_theme_constant_override("shadow_offset_x", 6)
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.custom_minimum_size = Vector2(0, 100)
	vbox.add_child(title)
	
	# Restart button with enhanced styling and interactivity
	restart_btn = Button.new()
	restart_btn.text = "RESTART"
	restart_btn.custom_minimum_size = Vector2(280, 70)
	restart_btn.add_theme_font_size_override("font_size", 28)
	restart_btn.add_theme_font_size_override("outline_size", 2)
	restart_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Set pivot to center for uniform scaling
	restart_btn.pivot_offset = Vector2(140, 35)
	
	# Style the button with vibrant gradient colors
	var normal_stylebox = StyleBoxFlat.new()
	normal_stylebox.bg_color = Color(0.15, 0.45, 0.85, 1.0)
	normal_stylebox.border_color = Color(0.5, 0.8, 1.0, 1.0)
	normal_stylebox.border_width_left = 4
	normal_stylebox.border_width_right = 4
	normal_stylebox.border_width_top = 4
	normal_stylebox.border_width_bottom = 4
	normal_stylebox.corner_radius_top_left = 16
	normal_stylebox.corner_radius_top_right = 16
	normal_stylebox.corner_radius_bottom_right = 16
	normal_stylebox.corner_radius_bottom_left = 16
	normal_stylebox.set_content_margin_all(12)
	normal_stylebox.shadow_size = 8
	normal_stylebox.shadow_color = Color(0, 0, 0, 0.5)
	
	var hover_stylebox = StyleBoxFlat.new()
	hover_stylebox.bg_color = Color(0.25, 0.55, 0.95, 1.0)
	hover_stylebox.border_color = Color(0.7, 0.95, 1.0, 1.0)
	hover_stylebox.border_width_left = 4
	hover_stylebox.border_width_right = 4
	hover_stylebox.border_width_top = 4
	hover_stylebox.border_width_bottom = 4
	hover_stylebox.corner_radius_top_left = 16
	hover_stylebox.corner_radius_top_right = 16
	hover_stylebox.corner_radius_bottom_right = 16
	hover_stylebox.corner_radius_bottom_left = 16
	hover_stylebox.set_content_margin_all(12)
	hover_stylebox.shadow_size = 12
	hover_stylebox.shadow_color = Color(0.2, 0.5, 0.95, 0.7)
	
	var pressed_stylebox = StyleBoxFlat.new()
	pressed_stylebox.bg_color = Color(0.1, 0.35, 0.75, 1.0)
	pressed_stylebox.border_color = Color(0.3, 0.6, 0.9, 1.0)
	pressed_stylebox.border_width_left = 4
	pressed_stylebox.border_width_right = 4
	pressed_stylebox.border_width_top = 4
	pressed_stylebox.border_width_bottom = 4
	pressed_stylebox.corner_radius_top_left = 16
	pressed_stylebox.corner_radius_top_right = 16
	pressed_stylebox.corner_radius_bottom_right = 16
	pressed_stylebox.corner_radius_bottom_left = 16
	pressed_stylebox.set_content_margin_all(12)
	pressed_stylebox.shadow_size = 4
	pressed_stylebox.shadow_color = Color(0, 0, 0, 0.3)
	
	restart_btn.add_theme_stylebox_override("normal", normal_stylebox)
	restart_btn.add_theme_stylebox_override("hover", hover_stylebox)
	restart_btn.add_theme_stylebox_override("pressed", pressed_stylebox)
	restart_btn.add_theme_stylebox_override("focus", hover_stylebox)
	restart_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	restart_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	restart_btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	
	vbox.add_child(restart_btn)
	
	# Button press feedback with animation
	restart_btn.pressed.connect(func():
		_button_press_feedback()
		await get_tree().create_timer(0.3).timeout
		get_tree().paused = false
		get_tree().reload_current_scene()
	)
	
	# Button hover feedback
	restart_btn.mouse_entered.connect(func():
		_play_button_scale_animation(1.08)
	)
	restart_btn.mouse_exited.connect(func():
		_play_button_scale_animation(1.0)
	)
	
	# Start fully transparent
	vbox.modulate.a = 0.0
	
	_animate_in()

func _animate_in() -> void:
	# Fade in background
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(bg, "color", Color(0.0, 0.0, 0.0, 0.75), 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Fade in UI with scale for bounce effect
	vbox.scale = Vector2(0.8, 0.8)
	tw.tween_property(vbox, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(vbox, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Wait for fade-in, then pause the game underneath
	var pause_timer = get_tree().create_timer(1.2)
	pause_timer.timeout.connect(func():
		get_tree().paused = true
	)

func _play_button_scale_animation(target_scale: float) -> void:
	if btn_tween and btn_tween.is_valid():
		btn_tween.kill()
	
	btn_tween = create_tween()
	btn_tween.set_trans(Tween.TRANS_ELASTIC)
	btn_tween.set_ease(Tween.EASE_OUT)
	btn_tween.tween_property(restart_btn, "scale", Vector2(target_scale, target_scale), 0.3)

func _button_press_feedback() -> void:
	# Quick scale down and back up for click feedback
	var tw = create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(restart_btn, "scale", Vector2(0.95, 0.95), 0.1)
	tw.tween_property(restart_btn, "scale", Vector2(1.0, 1.0), 0.15)
