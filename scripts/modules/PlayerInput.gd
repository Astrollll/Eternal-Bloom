extends RefCounted
class_name PlayerInput

static func ensure_actions() -> void:
	# Make sure all movement and combat input actions exist before gameplay starts.
	ensure_move_actions()
	ensure_attack_action()
	ensure_dash_action()

static func read_move_input() -> Vector2:
	# Combine mapped actions and direct keys so keyboard movement works even before input maps are customized.
	var x := 0.0
	var y := 0.0

	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		x -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		x += 1.0
	if Input.is_action_pressed("move_up") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		y -= 1.0
	if Input.is_action_pressed("move_down") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		y += 1.0

	if x != 0.0 or y != 0.0:
		return Vector2(x, y).normalized()

	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

static func ensure_move_actions() -> void:
	# Bind the standard WASD and arrow keys to the movement actions.
	_bind_action_key("move_left", KEY_A)
	_bind_action_key("move_left", KEY_LEFT)
	_bind_action_key("move_right", KEY_D)
	_bind_action_key("move_right", KEY_RIGHT)
	_bind_action_key("move_up", KEY_W)
	_bind_action_key("move_up", KEY_UP)
	_bind_action_key("move_down", KEY_S)
	_bind_action_key("move_down", KEY_DOWN)

static func ensure_attack_action() -> void:
	# Bind left click to the attack action if it is not already present.
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")

	for existing in InputMap.action_get_events("attack"):
		if existing is InputEventMouseButton and existing.button_index == (MOUSE_BUTTON_LEFT as MouseButton):
			return

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT as MouseButton
	InputMap.action_add_event("attack", event)

static func ensure_dash_action() -> void:
	# Bind right click to the dash action if it is not already present.
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")

	for existing in InputMap.action_get_events("dash"):
		if existing is InputEventMouseButton and existing.button_index == (MOUSE_BUTTON_RIGHT as MouseButton):
			return

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT as MouseButton
	InputMap.action_add_event("dash", event)

static func _bind_action_key(action_name: String, keycode: Key) -> void:
	# Attach a physical key to an action only once to avoid duplicate bindings.
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for existing in InputMap.action_get_events(action_name):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return

	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)
