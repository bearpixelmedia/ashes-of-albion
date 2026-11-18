extends Control
## Title / intro menu (concept image 1). Enter World drops straight into
## the world with the last committed class (Fighter by default),
## Character Select opens the eight-archetype picker, Settings is a
## Phase 6 stub, and Exit quits. Behind the panel a small 3D diorama
## (two torches and a banner on a moonlit floor) orbits slowly.

const GOLD_BRIGHT := Color(1.0, 0.82, 0.35)

var _starting := false

@onready var status_label: Label = %StatusLabel
@onready var camera_pivot: Node3D = %CameraPivot


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_style_buttons()
	%EnterWorld.grab_focus()


## The gold primary and dark secondaries come from the shared UiStyle helper.
func _style_buttons() -> void:
	var gold := UiStyle.gold()
	var dark := UiStyle.dark()
	var hover := UiStyle.dark_hover()
	UiStyle.paint(%EnterWorld, gold, gold, gold)
	for button in [%CharacterSelect, %TownHall, %Settings, %Exit]:
		UiStyle.paint(button, dark, hover, dark, hover)


func _process(delta: float) -> void:
	camera_pivot.rotation.y += delta * 0.06


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()


## Enter World: keep the committed class and load the world scene.
func start_world() -> void:
	if _starting:
		return
	_starting = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")


## Character Select: open the archetype picker.
func open_character_select() -> void:
	if _starting:
		return
	_starting = true
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")


## Town Hall: the citizenship and mayoral-ballot panel.
func open_town_hall() -> void:
	if _starting:
		return
	_starting = true
	get_tree().change_scene_to_file("res://scenes/town_hall.tscn")


## Settings stub — the real screen lands in Phase 6.
func show_settings() -> void:
	status_label.text = "Settings arrive in Phase 6 — audio, keybinds and camera."
	status_label.add_theme_color_override("font_color", GOLD_BRIGHT)


func _on_enter_world() -> void:
	start_world()


func _on_character_select() -> void:
	open_character_select()


func _on_town_hall() -> void:
	open_town_hall()


func _on_settings() -> void:
	show_settings()


func _on_exit() -> void:
	get_tree().quit()
