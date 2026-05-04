extends RefCounted
class_name PlayerSkin

const FRAME_SIZE := 24

static func build_skin_frames(walk_idle_tex: Texture2D, attack_tex: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	_add_skin_anim(frames, "idle_left", walk_idle_tex, [Vector2i(0, 0), Vector2i(1, 0)], 6.0, true)
	_add_skin_anim(frames, "idle_right", walk_idle_tex, [Vector2i(2, 0), Vector2i(3, 0)], 6.0, true)
	_add_skin_anim(frames, "walk_down", walk_idle_tex, [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)], 10.0, true)
	_add_skin_anim(frames, "walk_up", walk_idle_tex, [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)], 10.0, true)
	_add_skin_anim(frames, "walk_left", walk_idle_tex, [Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2)], 10.0, true)
	_add_skin_anim(frames, "walk_right", walk_idle_tex, [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)], 10.0, true)
	_add_skin_anim(frames, "attack_left", attack_tex, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)], 14.0, false)
	_add_skin_anim(frames, "attack_right", attack_tex, [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)], 14.0, false)
	return frames

static func _add_skin_anim(frames: SpriteFrames, anim_name: StringName, atlas: Texture2D, cells: Array[Vector2i], speed: float, loop: bool) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, speed)
	frames.set_animation_loop(anim_name, loop)
	for cell in cells:
		var frame := AtlasTexture.new()
		frame.atlas = atlas
		frame.region = Rect2(
			cell.x * FRAME_SIZE,
			cell.y * FRAME_SIZE,
			FRAME_SIZE,
			FRAME_SIZE
		)
		frames.add_frame(anim_name, frame)
