extends Control
## Title screen (concept image 1): the front door of the prototype. Enter
## World drops straight into the world with the last committed class,
## Character Select opens the champion picker, Settings toggles a small
## options panel (master volume + fullscreen) and Exit quits.

const MAIN_SCENE := "res://scenes/main.tscn"
const SELECT_SCENE := "res://scenes/character_select.tscn"

## Where this screen last asked to go. Smoke tests flip auto_navigate off and
## assert this instead of letting a scene change tear the test down.
var requested_scene := ""
var auto_navigate := true

@onready var title_label: Label = %TitleLabel
@onready var continue_label: Label = %ContinueLabel
@onready var enter_button: Button = %EnterWorld
@onready var character_button: Button = %CharacterSelect
@onready var settings_button: Button = %Settings
@onready var exit_button: Button = %Exit
@onready var settings_panel: Control = %SettingsPanel
@onready var volume_slider: HSlider = %VolumeSlider
@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var settings_back: Button = %SettingsBack


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	enter_button.pressed.connect(enter_world)
	character_button.pressed.connect(open_character_select)
	settings_button.pressed.connect(open_settings)
	exit_button.pressed.connect(quit_game)
	settings_back.pressed.connect(close_settings)
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	settings_panel.visible = false
	volume_slider.value = clampf(db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0, 0.0, 100.0)
	fullscreen_check.button_pressed = \
			DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	var champion := str(ClassKit.by_id(ClassKit.selected).get("name", "Fighter"))
	continue_label.text = "Continue as the %s" % champion
	enter_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	if event.keycode == KEY_ESCAPE and settings_panel.visible:
		close_settings()


# --- navigation ---------------------------------------------------------------

## Enter World: straight into the world with the last committed class.
func enter_world() -> void:
	go_to(MAIN_SCENE)


func open_character_select() -> void:
	go_to(SELECT_SCENE)


func go_to(path: String) -> void:
	requested_scene = path
	if auto_navigate:
		get_tree().change_scene_to_file(path)


# --- settings -----------------------------------------------------------------

func open_settings() -> void:
	settings_panel.visible = true
	volume_slider.grab_focus()


func close_settings() -> void:
	settings_panel.visible = false
	settings_button.grab_focus()


func _on_volume_changed(value: float) -> void:
	var linear := clampf(value / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(0, linear <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(linear, 0.0001)))


func _on_fullscreen_toggled(pressed: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if pressed \
			else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func quit_game() -> void:
	get_tree().quit()
