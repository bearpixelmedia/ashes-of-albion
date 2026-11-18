extends Control
## Character-select screen (concept image 3): character slots on the left,
## the chosen champion on a lit dais in the centre, the eight-archetype
## picker on the right and the action bar below. Fighter and Ranger are
## playable in this build; the other six can be previewed on the dais but
## Enter World stays disabled for them. Enter World commits the choice to
## ClassKit.selected and loads the world.

const FIGURE_SCENE := preload("res://scenes/archetype_figure.tscn")

const GOLD := Color(0.85, 0.66, 0.2)
const GOLD_BRIGHT := Color(1.0, 0.82, 0.35)
const DIM_TEXT := Color(0.62, 0.64, 0.7)

var selected_index := 2  # Fighter, matching the concept layout
var rows: Array = []
var figure = null  # the preview champion; untyped (its script owns members)
var _starting := false

@onready var row_list: VBoxContainer = %RowList
@onready var figure_anchor: Node3D = %FigureAnchor
@onready var preview_camera: Camera3D = %PreviewCamera
@onready var enter_button: Button = %EnterWorld
@onready var status_label: Label = %StatusLabel

var _style_base: StyleBoxFlat
var _style_hover: StyleBoxFlat
var _style_selected: StyleBoxFlat


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_styles()
	_build_rows()
	_style_buttons()
	var resume := ClassKit.index_of(ClassKit.selected)
	if resume >= 0:
		selected_index = resume
	select_class(selected_index)
	preview_camera.look_at(Vector3(0, 1.3, 0))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_title()
		return
	if not (event is InputEventKey) or not event.pressed:
		return
	var key := event as InputEventKey
	if key.keycode == KEY_UP or key.keycode == KEY_W:
		select_class(selected_index - 1)
	elif key.keycode == KEY_DOWN or key.keycode == KEY_S:
		select_class(selected_index + 1)
	elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		start_world()


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
	return ClassKit.selected


## Back: return to the title screen without committing anything.
func _go_title() -> void:
	if _starting:
		return
	_starting = true
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


## Enter World: commit the pick, then load the world scene.
func start_world() -> void:
	if enter_button.disabled or _starting:
		return
	_starting = true
	commit_selection()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# --- construction ------------------------------------------------------------

func _build_styles() -> void:
	_style_base = _style(Color(0.07, 0.075, 0.11, 0.95), Color(0.5, 0.42, 0.22, 0.5), 1)
	_style_hover = _style(Color(0.1, 0.1, 0.15, 0.98), GOLD, 1)
	_style_selected = _style(Color(0.14, 0.1, 0.05, 0.98), GOLD_BRIGHT, 2)


## The action bar uses the shared gold/dark boxes; Back hovers on the scene's
## selected-card gold, as in the concept.
func _style_buttons() -> void:
	var gold := UiStyle.gold()
	var dark := UiStyle.dark()
	UiStyle.paint(enter_button, gold, gold, gold)
	enter_button.add_theme_stylebox_override("disabled", dark)
	var back: Button = $Back
	back.add_theme_stylebox_override("normal", dark)
	for node_name in ["CreateNew", "Delete"]:
		var button: Button = get_node(node_name)
		button.add_theme_stylebox_override("normal", dark)
		button.add_theme_stylebox_override("disabled", dark)


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
		stack.offset_left = 14
		stack.offset_top = 4
		stack.offset_right = -14
		stack.offset_bottom = -4
		row_list.add_child(row)
		rows.append(row)
	_apply_row_styles()


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
