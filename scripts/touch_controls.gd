extends Control
## Touch controls for phones and tablets: a floating left stick for movement
## (push it to the rim to sprint), drag-to-look over the rest of the screen and
## a right-hand cluster for the actions the keyboard holds today — attack, both
## hotbar skills, lock-on, jump and the in-world pause menu.
##
## The pad shows itself only on a touch device (or when the game is launched
## with `--touch`, so the layout can be checked on a desktop). Every pointer is
## tracked by touch index, so moving, looking and swinging at the same time all
## work. Desktop mouse play never sees the pad: on a device with a touchscreen
## the mouse is ignored, because the engine re-emits mouse events from touches.

signal menu_pressed

const GOLD := Color(0.85, 0.66, 0.2)
const CREAM := Color(0.95, 0.91, 0.82)

const STICK_ZONE := 0.42  # left share of the screen that belongs to the stick
const DEADZONE := 0.16
const SPRINT_AT := 0.94  # a full push sprints, like holding Shift
const NO_PRESS := -99

var player = null  # the live player; untyped so its touch_* fields resolve
var pause_menu = null
var enabled := false
var accept_mouse := false  # desktop testing only; touchscreens never need it
var buttons: Array = []  # {id, center, radius, caption, name, press}
var stick_active := false
var move_vector := Vector2.ZERO

var _stick_index := -1
var _stick_base := Vector2.ZERO
var _stick_radius := 104.0
var _knob_radius := 46.0
var _home_center := Vector2.ZERO
var _look_index := -1
var _look_last := Vector2.ZERO
var _mouse_down := false
var _ui_scale := 1.0
var _layout_size := Vector2.ZERO
var _class_id := ""
var _skill_names: Array = []


static func is_available() -> bool:
	## True on a touch device, or when launched with `--touch`.
	if OS.get_cmdline_args().has("--touch") or OS.get_cmdline_user_args().has("--touch"):
		return true
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") \
			or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _ready() -> void:
	# Keep ticking while the world is paused so the stick can release itself;
	# _input drops everything while paused, so the pad never acts behind a menu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout)
	_layout()
	visible = false
	set_process(false)
	set_process_input(false)


## Attach the pad to a running world: the champion it drives and the pause
## menu its MENU button opens.
func bind(target_player, target_menu) -> void:
	player = target_player
	pause_menu = target_menu
	if pause_menu != null and not menu_pressed.is_connected(pause_menu.open):
		menu_pressed.connect(pause_menu.open)
	set_enabled(is_available())


func set_enabled(on: bool) -> void:
	enabled = on
	visible = on
	set_process(on)
	set_process_input(on)
	accept_mouse = on and not DisplayServer.is_touchscreen_available() \
			and not OS.has_feature("mobile")
	if on:
		_layout()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_release_all()
	queue_redraw()


## The pad's button with this id, or an empty dictionary. Used by the headless
## suite to tap the same targets a thumb would.
func button(id: String) -> Dictionary:
	for entry in buttons:
		if str(entry["id"]) == id:
			return entry
	return {}


func _process(_delta: float) -> void:
	if size != _layout_size:
		_layout()
	_refresh_skill_names()
	if get_tree().paused:
		_release_all()  # a paused run must not keep walking
	queue_redraw()


# --- input ---------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not enabled or get_tree().paused or not is_instance_valid(player):
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_pointer(touch.index, touch.position, touch.pressed)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_drag(drag.index, drag.position)
	elif accept_mouse and (event is InputEventMouseButton):
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT:
			_pointer(-1, click.position, click.pressed)
	elif accept_mouse and (event is InputEventMouseMotion) and _mouse_down:
		var motion := event as InputEventMouseMotion
		_drag(-1, motion.position)


## One pointer down or up: a button takes the touch, else the left zone starts
## the stick, else the rest of the screen drags the camera.
func _pointer(index: int, at: Vector2, pressed: bool) -> void:
	if pressed:
		if index == -1:
			_mouse_down = true
		for entry in buttons:
			if at.distance_to(entry["center"]) <= float(entry["radius"]) * 1.12:
				entry["press"] = index
				_press(entry)
				return
		if _stick_index == -1 and at.x <= size.x * STICK_ZONE and at.y >= size.y * 0.2:
			_stick_index = index
			_stick_base = at
			stick_active = true
			_update_stick(at)
			return
		if _look_index == -1:
			_look_index = index
			_look_last = at
	else:
		if index == -1:
			_mouse_down = false
		for entry in buttons:
			if int(entry["press"]) == index:
				entry["press"] = NO_PRESS
		if index == _stick_index:
			_stick_index = -1
			stick_active = false
			move_vector = Vector2.ZERO
			if is_instance_valid(player):
				player.touch_move = Vector2.ZERO
				player.touch_sprint = false
		if index == _look_index:
			_look_index = -1
	queue_redraw()


func _drag(index: int, at: Vector2) -> void:
	if index == _stick_index:
		_update_stick(at)
	elif index == _look_index:
		var relative := at - _look_last
		_look_last = at
		if is_instance_valid(player):
			player.look(relative)


func _update_stick(at: Vector2) -> void:
	var offset := at - _stick_base
	if offset.length() > _stick_radius:
		offset = offset.normalized() * _stick_radius
	var strength := offset.length() / _stick_radius
	move_vector = offset / _stick_radius if strength >= DEADZONE else Vector2.ZERO
	if is_instance_valid(player):
		player.touch_move = move_vector
		player.touch_sprint = strength >= SPRINT_AT and move_vector != Vector2.ZERO
	queue_redraw()


func _press(entry: Dictionary) -> void:
	if not is_instance_valid(player):
		return
	match str(entry["id"]):
		"attack":
			player.attack()
		"skill1":
			player.use_skill_1()
		"skill2":
			player.use_skill_2()
		"lock":
			player.toggle_lock_on()
		"jump":
			player.touch_jump = true
		"menu":
			# The menu pauses the tree before the finger lifts: drop the pad's
			# state now so nothing is still held when the run resumes.
			entry["press"] = NO_PRESS
			_release_all()
			menu_pressed.emit()


func _release_all() -> void:
	_stick_index = -1
	_look_index = -1
	_mouse_down = false
	stick_active = false
	move_vector = Vector2.ZERO
	for entry in buttons:
		entry["press"] = NO_PRESS
	if is_instance_valid(player):
		player.touch_move = Vector2.ZERO
		player.touch_sprint = false


# --- layout and drawing ---------------------------------------------------------

func _button(id: String, center: Vector2, radius: float, caption: String) -> Dictionary:
	return {
		"id": id, "center": center, "radius": radius,
		"caption": caption, "name": "", "press": NO_PRESS,
	}


## Everything is measured from the pad's own rect, so the cluster stays in the
## corners when the window (or the phone's safe area) changes shape.
func _layout() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	_layout_size = size
	_ui_scale = clampf(minf(size.x / 1600.0, size.y / 900.0), 0.5, 2.0)
	var w := size.x
	var h := size.y
	var s := _ui_scale
	_stick_radius = 104.0 * s
	_knob_radius = 46.0 * s
	_home_center = Vector2(30.0 * s + _stick_radius, h - 190.0 * s - _stick_radius)
	buttons = [
		_button("attack", Vector2(w - 118.0 * s, h - 128.0 * s), 62.0 * s, "ATK"),
		_button("skill1", Vector2(w - 252.0 * s, h - 186.0 * s), 48.0 * s, "1"),
		_button("skill2", Vector2(w - 226.0 * s, h - 62.0 * s), 48.0 * s, "2"),
		_button("lock", Vector2(w - 146.0 * s, h - 268.0 * s), 42.0 * s, "LOCK"),
		_button("jump", Vector2(w - 336.0 * s, h - 276.0 * s), 42.0 * s, "JUMP"),
		_button("menu", Vector2(w - 58.0 * s, 252.0 * s), 32.0 * s, "MENU"),
	]
	_class_id = ""
	_refresh_skill_names()
	queue_redraw()


## Slot captions follow the class: the fighter's Cleave and Second Wind become
## the ranger's Power Shot and Tumble after a class change.
func _refresh_skill_names() -> void:
	if not is_instance_valid(player):
		return
	var id := str(player.class_id)
	if id == _class_id:
		return
	_class_id = id
	_skill_names = ClassKit.skill_names(id)
	for entry in buttons:
		match str(entry["id"]):
			"skill1":
				entry["name"] = _skill_name(0)
			"skill2":
				entry["name"] = _skill_name(1)


func _skill_name(index: int) -> String:
	if index >= _skill_names.size():
		return ""
	return str(_skill_names[index]).to_upper()


func _cooldown(entry: Dictionary) -> float:
	if not is_instance_valid(player):
		return 0.0
	match str(entry["id"]):
		"skill1":
			return maxf(player.skill1_cd, 0.0)
		"skill2":
			return maxf(player.skill2_cd, 0.0)
	return 0.0


func _draw() -> void:
	if not enabled:
		return
	var font := ThemeDB.fallback_font
	if stick_active:
		draw_circle(_stick_base, _stick_radius, Color(0.05, 0.06, 0.1, 0.4))
		draw_arc(_stick_base, _stick_radius, 0.0, TAU, 48,
				Color(GOLD.r, GOLD.g, GOLD.b, 0.75), 2.0, true)
		var knob: Vector2 = _stick_base + move_vector * _stick_radius
		draw_circle(knob, _knob_radius, Color(0.18, 0.15, 0.09, 0.82))
		draw_arc(knob, _knob_radius, 0.0, TAU, 40,
				Color(GOLD.r, GOLD.g, GOLD.b, 0.9), 2.0, true)
	else:
		# Resting ghost ring: where the thumb goes when it is not on the glass.
		draw_circle(_home_center, _stick_radius, Color(0.05, 0.06, 0.1, 0.16))
		draw_arc(_home_center, _stick_radius, 0.0, TAU, 48,
				Color(GOLD.r, GOLD.g, GOLD.b, 0.3), 2.0, true)
		_text(font, _home_center, "MOVE", int(14.0 * _ui_scale),
				Color(0.9, 0.9, 0.95, 0.4))
	for entry in buttons:
		var center: Vector2 = entry["center"]
		var radius := float(entry["radius"])
		var held := int(entry["press"]) != NO_PRESS
		var cooling := _cooldown(entry)
		var fill := Color(0.06, 0.065, 0.1, 0.5)
		if held:
			fill = Color(0.18, 0.14, 0.07, 0.75)
		elif cooling > 0.0:
			fill = Color(0.04, 0.045, 0.06, 0.55)
		draw_circle(center, radius, fill)
		draw_arc(center, radius, 0.0, TAU, 44,
				Color(GOLD.r, GOLD.g, GOLD.b, 0.95 if held else 0.55), 2.0, true)
		var caption := str(entry["caption"])
		if cooling > 0.0:
			caption = str(ceili(cooling))
		var tint := CREAM if held else Color(CREAM.r, CREAM.g, CREAM.b, 0.92)
		_text(font, center, caption, int(radius * 0.5), tint)
		var label := str(entry["name"])
		if label != "" and cooling <= 0.0:
			_text(font, center + Vector2(0, radius * 0.66), label,
					int(radius * 0.27), Color(0.85, 0.8, 0.66, 0.9))


func _text(font: Font, center: Vector2, text: String, font_size: int, color: Color) -> void:
	var width := 220.0 * _ui_scale
	draw_string(font, center + Vector2(-width * 0.5, font_size * 0.36), text,
			HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
