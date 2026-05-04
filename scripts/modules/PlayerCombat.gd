extends RefCounted
class_name PlayerCombat

const ATTACK_LEFT: StringName = &"attack_left"
const ATTACK_RIGHT: StringName = &"attack_right"
const IDLE_LEFT: StringName = &"idle_left"
const IDLE_RIGHT: StringName = &"idle_right"

static func attack_animation_for_facing(facing_right: bool) -> StringName:
	return ATTACK_RIGHT if facing_right else ATTACK_LEFT

static func idle_animation_for_facing(facing_right: bool) -> StringName:
	return IDLE_RIGHT if facing_right else IDLE_LEFT

static func is_attack_animation(animation_name: StringName) -> bool:
	return animation_name == ATTACK_LEFT or animation_name == ATTACK_RIGHT
