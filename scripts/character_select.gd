extends Control
## Character-select screen (concept image 3): character slots on the left,
## the chosen champion on a lit dais in the centre, the eight-archetype
## picker on the right and the action bar below. Fighter and Ranger are
## playable in this build; the other six can be previewed on the dais but
## Enter World stays disabled for them. Enter World commits the choice to
## ClassKit.selected and loads the world; Back (or Esc) returns to the title.

const FIGURE_SCENE := preload("res://scenes/archetype_figure.tscn")
const HERALDRY := preload("res://scripts/heraldic_crest.gd")
const TITLE_SCENE := "res://scenes/title_screen.tscn"

const GOLD := Color(0.85, 0.66, 0.2)
const GOLD_BRIGHT := Color(1.0, 0.82, 0.35)
const DIM_TEXT := Color(0.62, 0.64, 0.7)

var selected_index := 2  # Fighter, matching the concept layout
var rows: Array = []
var figure = null  # the preview champion; untyped (its script owns members)
var _starting := false

## Where this screen last asked to go. Smoke tests flip auto_navigate off and
## assert this instead of letting a scene change tear the test down.
var requested_scene := ""
var auto_navigate := true

@onready var row_list: VBoxContainer = %RowList
@onready var figure_anchor: Node3D = %FigureAnchor
@onready var preview_camera: Camera3D = %PreviewCamera
@onready var enter_button: Button = %EnterWorld
@onready var back_button: Button = %Back
@onready var status_label: Label = %StatusLabel
@onready var slot_level: Label = $LeftPanel/Slot1/Slot1Meta

var _style_base: StyleBoxFlat
var _style_hover: StyleBoxFlat
var _style_selected: StyleBoxFlat


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	slot_level.text = "Level %d" % Progression.level
	_build_styles()
	_build_rows()
	var resume := ClassKit.index_of(ClassKit.selected)
	if resume >= 0:
		selected_index = resume
	select_class(selected_index)
	preview_camera.look_at(Vector3(0, 1.5, 0))
	back_button.pressed.connect(back_to_title)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var key := event as InputEventKey
	if key.keycode == KEY_UP or key.keycode == KEY_W:
		select_class(selected_index - 1)
	elif key.keycode == KEY_DOWN or key.keycode == KEY_S:
		select_class(selected_index + 1)
	elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		start_world()
	elif key.keycode == KEY_ESCAPE:
		back_to_title()


## Select an archetype: highlight its row, swap the dais figure, and gate
## Enter World on playability. Wraps around the roster.
func select_class(index: int) -> void:
	selected_index = posmod(index, ClassKit.ARCHETYPES.size())
	var definition := ClassKit.by_index(selected_index)
	_apply_row_styles()
	if figure != null:
		figure.queue_free()
	figure = FIGURE_SCENE.instantiate()  # untyped: the figure owns its members
	figure.archetype_index = selected_index
	figure_anchor.add_child(figure)
	if figure.nameplate != null:
		figure.nameplate.visible = false  # the picker already names the class
	var playable := ClassKit.is_playable(str(definition["id"]))
	enter_button.disabled = not playable
	if playable:
		status_label.text = "Ready to enter Albion as the %s." % definition["name"]
		status_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	else:
		status_label.text = "%s is not playable in this build — choose Fighter or Ranger." \
				% definition["name"]
		status_label.add_theme_color_override("font_color", DIM_TEXT)


## Commit the pick to the shared selection the world reads on boot.
## Returns the committed class id (start_world wraps this).
func commit_selection() -> String:
	ClassKit.selected = str(ClassKit.by_index(selected_index)["id"])
	SaveGame.save()  # the pick is part of the persistent run
	return ClassKit.selected


## Enter World: commit the pick, then load the world scene.
func start_world() -> void:
	if enter_button.disabled or _starting:
		return
	_starting = true
	commit_selection()
	go_to("res://scenes/main.tscn")


## Back: leave the picker for the title screen without committing.
func back_to_title() -> void:
	go_to(TITLE_SCENE)


func go_to(path: String) -> void:
	requested_scene = path
	if auto_navigate:
		get_tree().change_scene_to_file(path)


# --- construction ------------------------------------------------------------

func _build_styles() -> void:
	_style_base = _style(Color(0.07, 0.075, 0.11, 0.95), Color(0.5, 0.42, 0.22, 0.5), 1)
	_style_hover = _style(Color(0.1, 0.1, 0.15, 0.98), GOLD, 1)
	_style_selected = _style(Color(0.14, 0.1, 0.05, 0.98), GOLD_BRIGHT, 2)


func _style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(6)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


## One button per archetype: name + concept flavor line, built from ClassKit
## so the picker always tracks the roster.
func _build_rows() -> void:
	for i in ClassKit.ARCHETYPES.size():
		var definition := ClassKit.ARCHETYPES[i]
		var row := Button.new()
		row.name = "Row%d" % i
		row.custom_minimum_size = Vector2(336, 62)
		row.pressed.connect(select_class.bind(i))
		var chip := _class_chip(definition, 36.0)
		row.add_child(chip)
		chip.position = Vector2(12, 13)
		var name_label := Label.new()
		name_label.text = str(definition["name"])
		name_label.add_theme_font_size_override("font_size", 19)
		name_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.86))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var blurb_label := Label.new()
		blurb_label.text = str(definition["blurb"])
		blurb_label.add_theme_font_size_override("font_size", 13)
		blurb_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
		blurb_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var stack := VBoxContainer.new()
		stack.name = "Text"
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(name_label)
		stack.add_child(blurb_label)
		row.add_child(stack)
		stack.set_anchors_preset(Control.PRESET_FULL_RECT)
		stack.offset_left = 58
		stack.offset_top = 4
		stack.offset_right = -12
		stack.offset_bottom = -4
		row_list.add_child(row)
		rows.append(row)
	_apply_row_styles()


## Small heraldic chip per archetype: the class colour in a gold-bordered
## shield with the tree crest, echoing the class icons of the concept art.
func _class_chip(definition: Dictionary, side: float) -> Panel:
	var chip := Panel.new()
	chip.custom_minimum_size = Vector2(side, side)
	chip.size = Vector2(side, side)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = definition["body"]
	style.border_color = GOLD
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	chip.add_theme_stylebox_override("panel", style)
	var crest = HERALDRY.new()
	crest.size = Vector2(side - 12.0, side - 12.0)
	crest.position = Vector2(6, 6)
	crest.ring = false
	crest.line_color = Color(1.0, 0.92, 0.68, 0.92)
	crest.line_width = 1.5
	chip.add_child(crest)
	return chip


func _apply_row_styles() -> void:
	for i in rows.size():
		var box: StyleBoxFlat
		if i == selected_index:
			box = _style_selected
		elif rows[i].is_hovered():
			box = _style_hover
		else:
			box = _style_base
		rows[i].add_theme_stylebox_override("normal", box)
		rows[i].add_theme_stylebox_override("pressed", _style_selected)
		rows[i].add_theme_stylebox_override("hover", _style_hover)
		rows[i].add_theme_stylebox_override("focus", _style_hover)
