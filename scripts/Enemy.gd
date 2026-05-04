extends CharacterBody2D
class_name Enemy

@export var move_speed: float = 145.0
@export var chase_range: float = 260.0
@export var attack_range: float = 34.0
@export var attack_cooldown: float = 0.8
@export var attack_damage: int = 10
@export var max_hp: int = 80
@export var hp_bar_offset: Vector2 = Vector2(0, -34)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

const WALK_IDLE_TEX: Texture2D = preload("res://assets/Tiny Wonder Forest 1.0/characters/main character old/walk and idle.png")
const ATTACK_TEX: Texture2D = preload("res://assets/Tiny Wonder Forest 1.0/characters/main character old/attack and die.png")

var player: CharacterBody2D
var facing_right: bool = false
var is_attacking: bool = false
var attack_cooldown_left: float = 0.0
var current_hp: int = 0
var is_dead: bool = false

var hp_bar_bg: Line2D
var hp_bar_fill: Line2D
var knockback_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("enemies")
	_build_sprite_frames()
	_setup_hp_bar()
	current_hp = max_hp
	_update_hp_bar()
	player = get_tree().current_scene.get_node_or_null("Player") as CharacterBody2D
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("idle_left")

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = knockback_velocity.move_toward(Vector2.ZERO, 1000.0 * delta)
		move_and_slide()
		return

	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 1000.0 * delta)

	if attack_cooldown_left > 0.0:
		attack_cooldown_left = max(0.0, attack_cooldown_left - delta)

	if player == null or not is_instance_valid(player):
		player = get_tree().current_scene.get_node_or_null("Player") as CharacterBody2D
		velocity = knockback_velocity
		move_and_slide()
		return

	if is_attacking:
		velocity = knockback_velocity
		move_and_slide()
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()

	if dist > chase_range:
		velocity = knockback_velocity
		_play_idle()
		move_and_slide()
		return

	if dist <= attack_range and attack_cooldown_left <= 0.0:
		_start_attack(to_player)
		velocity = knockback_velocity
		move_and_slide()
		return

	var dir: Vector2 = to_player.normalized() if dist > 0.001 else Vector2.ZERO
	velocity = dir * move_speed + knockback_velocity
	_update_walk_anim(dir)
	move_and_slide()

func _start_attack(to_player: Vector2) -> void:
	is_attacking = true
	attack_cooldown_left = attack_cooldown
	if abs(to_player.x) >= abs(to_player.y):
		facing_right = to_player.x >= 0.0
	_play_anim("attack_right" if facing_right else "attack_left")

	if to_player.length() <= attack_range + 8.0:
		if player != null and is_instance_valid(player):
			if player.has_method("on_hit_by_enemy"):
				player.call("on_hit_by_enemy", attack_damage, to_player.normalized())
			elif player.has_method("take_damage"):
				player.call("take_damage", attack_damage, to_player.normalized())

func _on_animation_finished() -> void:
	if sprite.animation == &"attack_left" or sprite.animation == &"attack_right":
		is_attacking = false
		_play_idle()

func _update_walk_anim(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		_play_idle()
		return

	if abs(dir.x) >= abs(dir.y):
		if dir.x > 0.0:
			facing_right = true
			_play_anim("walk_right")
		else:
			facing_right = false
			_play_anim("walk_left")
	else:
		if dir.y > 0.0:
			_play_anim("walk_down")
		else:
			_play_anim("walk_up")

func _play_idle() -> void:
	_play_anim("idle_right" if facing_right else "idle_left")

func _play_anim(anim: StringName) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)

func on_hit_by_player(amount: int, direction: Vector2 = Vector2.ZERO) -> void:
	take_damage(amount, direction)

func take_damage(amount: int, direction: Vector2 = Vector2.ZERO) -> void:
	if is_dead or amount <= 0:
		return
	current_hp = max(0, current_hp - amount)
	_update_hp_bar()

	# Apply knockback to the enemy
	if direction != Vector2.ZERO:
		knockback_velocity = direction * 400.0

	var hit_tw: Tween = create_tween()
	hit_tw.tween_property(self , "modulate", Color(1.28, 0.72, 0.72, 1.0), 0.05)
	hit_tw.tween_property(self , "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)

	if current_hp <= 0:
		_die()

func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_play_anim("die_right" if facing_right else "die_left")
	
	var fade_tw: Tween = create_tween()
	# Wait for a portion of the death animation to play before fading
	fade_tw.tween_interval(1.2)
	fade_tw.tween_property(self , "modulate:a", 0.0, 0.8)
	fade_tw.tween_callback(queue_free)

func _setup_hp_bar() -> void:
	hp_bar_bg = Line2D.new()
	hp_bar_bg.width = 5.0
	hp_bar_bg.default_color = Color(0.12, 0.12, 0.12, 0.82)
	hp_bar_bg.position = hp_bar_offset
	hp_bar_bg.points = PackedVector2Array([Vector2(-18, 0), Vector2(18, 0)])
	hp_bar_bg.z_index = 100
	add_child(hp_bar_bg)

	hp_bar_fill = Line2D.new()
	hp_bar_fill.width = 3.0
	hp_bar_fill.default_color = Color(0.96, 0.26, 0.26, 0.95)
	hp_bar_fill.position = hp_bar_offset
	hp_bar_fill.points = PackedVector2Array([Vector2(-17, 0), Vector2(17, 0)])
	hp_bar_fill.z_index = 101
	add_child(hp_bar_fill)

func _update_hp_bar() -> void:
	if hp_bar_fill == null:
		return
	var pct: float = clampf(float(current_hp) / float(max(1, max_hp)), 0.0, 1.0)
	var half_w: float = 17.0
	hp_bar_fill.points = PackedVector2Array([Vector2(-half_w, 0), Vector2(-half_w + (half_w * 2.0 * pct), 0)])

func _build_sprite_frames() -> void:
	if sprite == null:
		return
	var frames: SpriteFrames = SpriteFrames.new()
	_add_anim(frames, "idle_left", WALK_IDLE_TEX, [Vector2i(0, 3), Vector2i(1, 3)], 6.0, true)
	_add_anim(frames, "idle_right", WALK_IDLE_TEX, [Vector2i(0, 1), Vector2i(1, 1)], 6.0, true)
	_add_anim(frames, "walk_down", WALK_IDLE_TEX, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)], 10.0, true)
	_add_anim(frames, "walk_up", WALK_IDLE_TEX, [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)], 10.0, true)
	_add_anim(frames, "walk_left", WALK_IDLE_TEX, [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)], 10.0, true)
	_add_anim(frames, "walk_right", WALK_IDLE_TEX, [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)], 10.0, true)
	_add_anim(frames, "attack_left", ATTACK_TEX, [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)], 14.0, false)
	_add_anim(frames, "attack_right", ATTACK_TEX, [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)], 14.0, false)
	_add_anim(frames, "die_left", ATTACK_TEX, [Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3)], 8.0, false)
	_add_anim(frames, "die_right", ATTACK_TEX, [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)], 8.0, false)
	sprite.sprite_frames = frames

func _add_anim(frames: SpriteFrames, anim_name: StringName, atlas: Texture2D, cells: Array[Vector2i], speed: float, loop: bool) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, speed)
	frames.set_animation_loop(anim_name, loop)
	for cell in cells:
		var frame: AtlasTexture = AtlasTexture.new()
		frame.atlas = atlas
		frame.region = Rect2(cell.x * 24, cell.y * 24, 24, 24)
		frames.add_frame(anim_name, frame)
