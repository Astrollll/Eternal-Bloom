extends StaticBody2D

@export var facing_left: bool = false
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var _base_y: float = 0.0
var _idle_time: float = 0.0

func _ready() -> void:
	anim.play("face_left" if facing_left else "face_right")
	_base_y = anim.position.y

func _process(delta: float) -> void:
	_idle_time += delta
	anim.position.y = _base_y + sin(_idle_time * 2.4) * 0.7
	var pulse := 0.93 + (sin(_idle_time * 1.85) * 0.07 + 0.07)
	anim.modulate = Color(pulse, pulse, pulse, 1.0)
