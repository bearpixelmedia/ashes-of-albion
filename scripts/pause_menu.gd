extends CanvasLayer
## In-world Esc menu: the way back out of a run. Opening it pauses the world
## and frees the mouse; Resume drops you back in, the other buttons leave for
## the front end (character select or the title screen).

signal skills_pressed

const SELECT_SCENE := "res://scenes/character_select.tscn"
const TITLE_SCENE := "res://scenes/title_screen.tscn"

## Where this menu last asked to go. Smoke tests flip auto_navigate off and
## assert this instead of letting a scene change tear the test down.
var requested_scene := ""
var auto_navigate := true
var is_open := false

@onready var root: Control = %Root
@onready var resume_button: Button = %Resume
@onready var skills_button: Button = %Skills
@onready var character_button: Button = %CharacterSelect
@onready var title_button: Button = %TitleScreen


func _ready() -> void:
	root.visible = false
	skills_button.pressed.connect(func() -> void: skills_pressed.emit())


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	if event.keycode != KEY_ESCAPE:
		return
	if is_open:
		close()
	else:
		open()
	get_viewport().set_input_as_handled()


# --- open / close -------------------------------------------------------------

func open() -> void:
	if is_open:
		return
	is_open = true
	root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	resume_button.grab_focus()


func close() -> void:
	if not is_open:
		return
	is_open = false
	root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- leave the run ------------------------------------------------------------

func go_to_character_select() -> void:
	go_to(SELECT_SCENE)


func go_to_title() -> void:
	go_to(TITLE_SCENE)


func go_to(path: String) -> void:
	requested_scene = path
	leave()
	if auto_navigate:
		get_tree().change_scene_to_file(path)


## Drop the overlay and unpause without touching the mouse: the next scene
## owns mouse mode.
func leave() -> void:
	is_open = false
	root.visible = false
	get_tree().paused = false
