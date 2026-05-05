extends CharacterBody2D

@export var speed: float = 250.0
@export var skin_overlay_offset: Vector2 = Vector2.ZERO
@export var dash_speed: float = 820.0
@export var dash_duration: float = 0.14
@export var dash_cooldown: float = 0.45
@export var afterimage_interval: float = 0.05
@export var afterimage_fade_time: float = 0.12
@export var afterimage_alpha: float = 0.34
@export var attack_range: float = 24.0
@export var melee_trigger_bonus: float = 34.0
@export var attack_half_size: Vector2 = Vector2(12, 10)
@export var attack_collision_mask: int = 1
@export var attack_impact_fade_time: float = 0.15
@export var max_hp: int = 220
@export var hp_bar_offset: Vector2 = Vector2(0, -34)
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

const DashVFXModule = preload("res://scripts/modules/DashVFX.gd")
const PlayerInputModule = preload("res://scripts/modules/PlayerInput.gd")
const PlayerCombatModule = preload("res://scripts/modules/PlayerCombat.gd")
const PlayerSkinModule = preload("res://scripts/modules/PlayerSkin.gd")
const PlayerAttackModule = preload("res://scripts/modules/PlayerAttack.gd")
const FRAME_SIZE: int = 24
const BASE_ATTACK_TEX: Texture2D = preload("res://assets/Tiny Wonder Forest 1.0/characters/main character/attack and die.png")
const SKIN_WALK_IDLE_TEX: Texture2D = preload("res://assets/Tiny Wonder Forest 1.0/characters/main character old/cat kigurumi walk and idle.png")
const SKIN_ATTACK_TEX: Texture2D = preload("res://assets/Tiny Wonder Forest 1.0/characters/main character/cat kigurumi attack and die.png")

var facing_right: bool = true
var is_attacking: bool = false
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.RIGHT
var dash_time_left: float = 0.0
var dash_cooldown_left: float = 0.0
var afterimage_time_left: float = 0.0
var skin_sprite: AnimatedSprite2D
var current_hp: int = 0
var hp_bar_bg: Line2D
var hp_bar_fill: Line2D
var knockback_velocity: Vector2 = Vector2.ZERO
var is_dead: bool = false
var death_fade_started: bool = false

func _ready() -> void:
	get_tree().paused = false
	PlayerInputModule.ensure_actions()
	_ensure_death_animations()
	_setup_skin_overlay()
	_setup_hp_bar()
	current_hp = max_hp
	_update_hp_bar()
	_sync_skin_to_base()
	sprite.animation_finished.connect(_on_sprite_animation_finished)

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	# Gradually decay knockback over time
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 1000.0 * delta)

	if dash_cooldown_left > 0.0:
		dash_cooldown_left = max(0.0, dash_cooldown_left - delta)

	# Press 'Tab' to toggle the cat kigurumi skin on and off
	if Input.is_action_just_pressed("ui_focus_next"):
		if skin_sprite and skin_sprite.visible:
			change_skin(null, null) # Swaps back to base character
		else:
			change_skin(SKIN_WALK_IDLE_TEX, SKIN_ATTACK_TEX) # Swaps to Cat Kigurumi

	if Input.is_action_just_pressed("dash") and _can_start_dash():
		_start_dash()

	if is_dashing:
		dash_time_left = max(0.0, dash_time_left - delta)
		velocity = dash_direction * dash_speed + knockback_velocity
		move_and_slide()
		_spawn_dash_afterimage(delta)
		_sync_skin_to_base()
		if dash_time_left <= 0.0:
			_end_dash()
		return

	if Input.is_action_just_pressed("attack") and not is_attacking:
		_start_attack()

	if is_attacking:
		velocity = knockback_velocity
		move_and_slide()
		_sync_skin_to_base()
		return

	var direction: Vector2 = PlayerInputModule.read_move_input()

	velocity = direction * speed + knockback_velocity
	move_and_slide()

	if direction == Vector2.ZERO:
		_play_anim("idle_right" if facing_right else "idle_left")
		_sync_skin_to_base()
		return

	if abs(direction.x) >= abs(direction.y):
		if direction.x > 0.0:
			facing_right = true
			_play_anim("walk_left")
		else:
			facing_right = false
			_play_anim("walk_right")
	else:
		if direction.y > 0.0:
			_play_anim("walk_down")
		else:
			_play_anim("walk_up")

	_sync_skin_to_base()

func _start_attack() -> void:
	is_attacking = true
	velocity = Vector2.ZERO
	
	var target = _get_nearest_enemy()
	var dist = global_position.distance_to(target.global_position) if target else INF
	var melee_trigger_range: float = attack_range + melee_trigger_bonus
	
	# If target is within melee range (with a small buffer), swing sword
	if target != null and dist <= melee_trigger_range:
		_play_anim(PlayerCombatModule.attack_animation_for_facing(facing_right))
		PlayerAttackModule.apply_melee_hit(
			self , facing_right, attack_range, attack_half_size,
			attack_collision_mask, attack_impact_fade_time
		)
	else:
		# Otherwise, shoot a projectile in the direction of the target or facing direction
		_play_anim(PlayerCombatModule.attack_animation_for_facing(facing_right))
		var shoot_dir = (target.global_position - global_position).normalized() if target else (Vector2.RIGHT if facing_right else Vector2.LEFT)
		PlayerAttackModule.shoot_projectile(self , shoot_dir, attack_collision_mask)

func _on_sprite_animation_finished() -> void:
	if is_dead and (sprite.animation == &"die_left" or sprite.animation == &"die_right"):
		_start_death_fade()
		return

	if PlayerCombatModule.is_attack_animation(sprite.animation):
		is_attacking = false
		_play_anim(PlayerCombatModule.idle_animation_for_facing(facing_right))

func _get_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var min_dist := INF
	for e in enemies:
		if not is_instance_valid(e): continue
		var d = global_position.distance_to(e.global_position)
		if d < min_dist:
			min_dist = d
			nearest = e as Node2D
	return nearest

func _setup_skin_overlay() -> void:
	skin_sprite = get_node_or_null("SkinOverlay") as AnimatedSprite2D
	if skin_sprite == null:
		skin_sprite = AnimatedSprite2D.new()
		skin_sprite.name = "SkinOverlay"
		add_child(skin_sprite)

	if skin_sprite.sprite_frames == null:
		skin_sprite.sprite_frames = PlayerSkinModule.build_skin_frames(SKIN_WALK_IDLE_TEX, SKIN_ATTACK_TEX)
	_ensure_skin_death_animations()

	skin_sprite.scale = sprite.scale
	skin_sprite.position = sprite.position + skin_overlay_offset
	skin_sprite.z_index = sprite.z_index + 1
	if skin_sprite.sprite_frames != null and skin_sprite.sprite_frames.has_animation(sprite.animation):
		skin_sprite.play(sprite.animation)
func _can_start_dash() -> bool:
	return not is_dashing and not is_attacking and dash_cooldown_left <= 0.0

func _start_dash() -> void:
	var input_dir: Vector2 = PlayerInputModule.read_move_input()
	if input_dir == Vector2.ZERO:
		dash_direction = Vector2.RIGHT if facing_right else Vector2.LEFT
	else:
		dash_direction = input_dir

	if abs(dash_direction.x) >= abs(dash_direction.y):
		facing_right = dash_direction.x >= 0.0

	is_dashing = true
	dash_time_left = dash_duration
	dash_cooldown_left = dash_cooldown
	afterimage_time_left = 0.0
	_spawn_dash_afterimage(0.0)

func _end_dash() -> void:
	is_dashing = false
	velocity = Vector2.ZERO

func _spawn_dash_afterimage(delta: float) -> void:
	afterimage_time_left -= delta
	while afterimage_time_left <= 0.0:
		_create_afterimage_sprite()
		afterimage_time_left += max(0.01, afterimage_interval)

func _create_afterimage_sprite() -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return

	var base_tex: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var skin_tex: Texture2D = null
	# Ensure we only fetch a skin texture if the skin is currently visible/equipped
	if skin_sprite != null and skin_sprite.visible and skin_sprite.sprite_frames != null and skin_sprite.sprite_frames.has_animation(skin_sprite.animation):
		skin_tex = skin_sprite.sprite_frames.get_frame_texture(skin_sprite.animation, skin_sprite.frame)

	DashVFXModule.spawn_afterimage(
		self ,
		root,
		global_position,
		sprite.z_index - 1,
		base_tex,
		sprite.scale,
		skin_tex,
		skin_sprite.scale if skin_sprite != null else Vector2.ONE,
		skin_overlay_offset,
		afterimage_alpha,
		afterimage_fade_time,
		dash_direction
	)

func _play_anim(anim_name: StringName) -> void:
	sprite.play(anim_name)
	if skin_sprite != null and skin_sprite.sprite_frames != null and skin_sprite.sprite_frames.has_animation(anim_name):
		skin_sprite.play(anim_name)

func _sync_skin_to_base() -> void:
	if skin_sprite == null:
		return
	skin_sprite.position = sprite.position + skin_overlay_offset
	skin_sprite.scale = sprite.scale
	if skin_sprite.animation != sprite.animation:
		skin_sprite.play(sprite.animation)
	skin_sprite.frame = sprite.frame
	skin_sprite.frame_progress = sprite.frame_progress

func _setup_hp_bar() -> void:
	hp_bar_bg = Line2D.new()
	hp_bar_bg.name = "HPBarBg"
	hp_bar_bg.width = 5.0
	hp_bar_bg.default_color = Color(0.12, 0.12, 0.12, 0.82)
	hp_bar_bg.position = hp_bar_offset
	hp_bar_bg.points = PackedVector2Array([Vector2(-18, 0), Vector2(18, 0)])
	hp_bar_bg.z_index = 100
	add_child(hp_bar_bg)

	hp_bar_fill = Line2D.new()
	hp_bar_fill.name = "HPBarFill"
	hp_bar_fill.width = 3.0
	hp_bar_fill.default_color = Color(0.35, 0.94, 0.45, 0.95)
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
	if pct > 0.5:
		hp_bar_fill.default_color = Color(0.35, 0.94, 0.45, 0.95)
	elif pct > 0.25:
		hp_bar_fill.default_color = Color(0.98, 0.78, 0.25, 0.95)
	else:
		hp_bar_fill.default_color = Color(0.96, 0.25, 0.25, 0.95)


## Updates the player's skin overlay textures at runtime.
## Pass null to both to effectively "unequip" the skin.
func change_skin(walk_idle_tex: Texture2D, attack_tex: Texture2D) -> void:
	if skin_sprite == null:
		_setup_skin_overlay()

	if walk_idle_tex == null or attack_tex == null:
		skin_sprite.visible = false
		return

	skin_sprite.visible = true
	skin_sprite.sprite_frames = PlayerSkinModule.build_skin_frames(walk_idle_tex, attack_tex)
	
	# Ensure the new skin is immediately synced to the current animation state
	_sync_skin_to_base()
	if skin_sprite.sprite_frames.has_animation(sprite.animation):
		skin_sprite.play(sprite.animation)

func take_damage(amount: int, knock_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead or amount <= 0:
		return
	current_hp = max(0, current_hp - amount)
	_update_hp_bar()

	# Utilize the previously unused knock_dir to provide visual feedback
	if knock_dir != Vector2.ZERO:
		knockback_velocity = knock_dir * 450.0

	var hit_tw: Tween = create_tween()
	hit_tw.tween_property(self , "modulate", Color(1.3, 0.7, 0.7, 1.0), 0.05)
	hit_tw.tween_property(self , "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)

	if current_hp <= 0:
		_die()

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	death_fade_started = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	_play_anim("die_right" if facing_right else "die_left")
	sprite.frame = 0
	if skin_sprite != null and skin_sprite.visible:
		skin_sprite.frame = 0

func _start_death_fade() -> void:
	if death_fade_started:
		return
	death_fade_started = true
	var fade_tw: Tween = create_tween()
	fade_tw.tween_interval(0.15)
	fade_tw.tween_property(self , "modulate:a", 0.0, 0.35)
	fade_tw.tween_callback(queue_free)

func on_hit_by_enemy(amount: int, direction: Vector2 = Vector2.ZERO) -> void:
	take_damage(amount, direction)

func _ensure_death_animations() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	_replace_death_animation(sprite.sprite_frames, &"die_left", BASE_ATTACK_TEX, 1)
	_replace_death_animation(sprite.sprite_frames, &"die_right", BASE_ATTACK_TEX, 3)

func _ensure_skin_death_animations() -> void:
	if skin_sprite == null or skin_sprite.sprite_frames == null:
		return
	_replace_death_animation(skin_sprite.sprite_frames, &"die_left", SKIN_ATTACK_TEX, 1)
	_replace_death_animation(skin_sprite.sprite_frames, &"die_right", SKIN_ATTACK_TEX, 3)

func _replace_death_animation(frames: SpriteFrames, anim_name: StringName, atlas: Texture2D, row: int) -> void:
	if frames.has_animation(anim_name):
		frames.remove_animation(anim_name)
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, 8.0)
	frames.set_animation_loop(anim_name, false)
	for col in range(0, 4):
		var frame := AtlasTexture.new()
		frame.atlas = atlas
		frame.region = Rect2(col * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
		frames.add_frame(anim_name, frame)
