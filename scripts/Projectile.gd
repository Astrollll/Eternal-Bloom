extends Area2D

var velocity: Vector2 = Vector2.ZERO
var damage: int = 15
var callback: Callable

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# Ensure the projectile faces its travel direction
	if velocity != Vector2.ZERO:
		rotation = velocity.angle()
	
	# Auto-destruct after 1.5 seconds to prevent memory leaks
	get_tree().create_timer(1.5).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += velocity * delta

func _on_body_entered(body: Node) -> void:
	# If we hit a damageable target, trigger the callback
	if callback.is_valid():
		callback.call(body)
	
	# Create a small impact effect before disappearing
	queue_free()