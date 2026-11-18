extends CanvasLayer
## Fighter Skill Tree (concept image 1): a full-screen board over the paused
## world. Swordcraft splits into Offensive and Defensive forms; each node
## carries ranks bought with skill points; Whirlwind, Armor Break and Bulwark
## are locked in this build; the Secondary Archetype rail gates at level 25.
## Every rank is pushed onto the live player kit immediately.

signal closed

const SKILL_ICON := preload("res://scripts/skill_icon.gd")
const GOLD := Color(0.85, 0.66, 0.2)
const GOLD_BRIGHT := Color(1.0, 0.82, 0.35)
const CREAM := Color(0.95, 0.91, 0.82)
const DIM := Color(0.62, 0.64, 0.7)

var is_open := false
var player = null  # the live world player; untyped so its kit fields resolve
var buttons: Dictionary = {}
var rank_labels: Dictionary = {}
var rail_unlocked := false
var secondary_buttons: Array = []

@onready var board: Control = %Board
@onready var node_layer: Control = %Nodes
@onready var title_label: Label = %Title
@onready var points_label: Label = %PointsLabel
@onready var orbs: HBoxContainer = %Orbs
@onready var status_label: Label = %Status
@onready var summary_label: Label = %Summary
@onready var rail_hint: Label = %RailHint
@onready var rail_lock: Control = $Board/Rail/RailLock
@onready var rail_shield: Control = $Board/Rail/RailShield
@onready var rail_box: VBoxContainer = $Board/Rail/Chips
@onready var reset_button: Button = %Reset
@onready var back_button: Button = %Back

var _style_base: StyleBoxFlat
var _style_hover: StyleBoxFlat
var _style_locked: StyleBoxFlat
var _orb_style: StyleBoxFlat


func _ready() -> void:
	SkillTreeData.ensure()
	board.visible = false
	_build_styles()
	_build_nodes()
	reset_button.pressed.connect(reset_all)
	back_button.pressed.connect(close)
	if get_tree().current_scene == self:
		open()  # running this scene directly (F6) shows the board
	else:
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey) or not event.pressed:
		return
	if event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


# --- open / close -------------------------------------------------------------

func open(target_player = null) -> void:
	if target_player != null:
		player = target_player
	SkillTreeData.ensure()
	is_open = true
	board.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	status_label.text = "Spend points on a node to rank it up."
	_refresh()


func close() -> void:
	if not is_open:
		return
	is_open = false
	board.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if player != null and is_instance_valid(player):
		SkillTreeData.apply_to(player)
	closed.emit()


# --- ranks --------------------------------------------------------------------

func spend(id: String) -> bool:
	var definition := SkillTreeData.node_by_id(id)
	if definition.is_empty():
		return false
	if not SkillTreeData.can_rank(id):
		status_label.text = _rejection(id, definition)
		_refresh()
		return false
	var rank := SkillTreeData.add_rank(id)
	status_label.text = "%s is now rank %d — %s" % [
		definition["name"], rank, definition["blurb"]]
	if player != null and is_instance_valid(player):
		SkillTreeData.apply_to(player)
	SaveGame.save()  # ranks are part of the persistent run
	_refresh()
	return true


func reset_all() -> void:
	SkillTreeData.reset()
	if player != null and is_instance_valid(player):
		SkillTreeData.apply_to(player)
	SaveGame.save()
	status_label.text = "Tree reset — every point refunded."
	_refresh()


## Pick the secondary archetype once the level-25 gate is open. The choice is
## identity only for now: no secondary kit exists yet, but it persists.
func choose_secondary(id: String) -> bool:
	if not Progression.secondary_unlocked() or ClassKit.by_id(id).is_empty():
		return false
	Progression.secondary = id
	status_label.text = "Secondary archetype set to %s." \
			% str(ClassKit.by_id(id).get("name", id))
	SaveGame.save()
	_refresh()
	return true


func _rejection(id: String, definition: Dictionary) -> String:
	if bool(definition["locked"]):
		return "%s is locked in this build." % definition["name"]
	if SkillTreeData.points_available() <= 0:
		return "No skill points left — reset the tree to reallocate them."
	return "%s is already at its maximum rank." % definition["name"]


# --- board --------------------------------------------------------------------

func _refresh() -> void:
	points_label.text = "Available Skill Points:  %d" % SkillTreeData.points_available()
	summary_label.text = "Ranks  %d / %d spent" % [
		SkillTreeData.points_spent(), Progression.points_total()]
	for definition in SkillTreeData.NODES:
		var id := str(definition["id"])
		var label: Label = rank_labels[id]
		var button: Button = buttons[id]
		if bool(definition["locked"]):
			label.text = "Locked"
			label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
			button.modulate = Color(0.6, 0.6, 0.66, 1.0)
		else:
			var max_rank := int(definition["max"])
			label.text = "" if max_rank <= 0 else "Rank %d/%d" % [
				SkillTreeData.rank_of(id), max_rank]
			button.modulate = Color.WHITE
			var maxed := max_rank > 0 and SkillTreeData.rank_of(id) >= max_rank
			label.add_theme_color_override("font_color",
					Color(0.5, 0.9, 0.55) if maxed else GOLD_BRIGHT)
	_rebuild_orbs()
	_refresh_rail()


func _refresh_rail() -> void:
	## Below level 25 the rail is a padlocked promise; at 25 it opens into the
	## eight secondary archetypes, and the pick is remembered in the save.
	rail_unlocked = Progression.secondary_unlocked()
	for child in rail_box.get_children():
		rail_box.remove_child(child)
		child.queue_free()
	secondary_buttons.clear()
	rail_lock.visible = not rail_unlocked
	rail_shield.visible = not rail_unlocked
	if not rail_unlocked:
		rail_hint.text = "Unlocks at Level 25"
		return
	var chosen := Progression.secondary
	rail_hint.text = "Unlocked — choose a secondary." if chosen == "" \
			else "Secondary: %s" % str(ClassKit.by_id(chosen).get("name", chosen))
	for definition in ClassKit.ARCHETYPES:
		var id := str(definition["id"])
		var button := Button.new()
		button.text = str(definition["name"])
		button.custom_minimum_size = Vector2(184, 22)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 11)
		var style := StyleBoxFlat.new()
		style.bg_color = definition["body"].darkened(0.55)
		style.border_color = Color(0.85, 0.66, 0.2, 0.95 if id == chosen else 0.3)
		style.set_border_width_all(2 if id == chosen else 1)
		style.set_corner_radius_all(4)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.pressed.connect(choose_secondary.bind(id))
		rail_box.add_child(button)
		secondary_buttons.append(button)


func _rebuild_orbs() -> void:
	for child in orbs.get_children():
		orbs.remove_child(child)
		child.queue_free()
	for i in mini(SkillTreeData.points_available(), 10):
		var orb := Panel.new()
		orb.custom_minimum_size = Vector2(24, 24)
		orb.size = Vector2(24, 24)
		orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		orb.add_theme_stylebox_override("panel", _orb_style)
		orbs.add_child(orb)


func _build_styles() -> void:
	_style_base = _node_style(Color(0.07, 0.065, 0.075, 0.96),
			Color(0.45, 0.38, 0.2, 0.8), 1)
	_style_hover = _node_style(Color(0.13, 0.1, 0.05, 0.98), GOLD_BRIGHT, 2)
	_style_locked = _node_style(Color(0.05, 0.05, 0.06, 0.9),
			Color(0.3, 0.31, 0.36, 0.8), 1)
	_orb_style = StyleBoxFlat.new()
	_orb_style.bg_color = GOLD_BRIGHT
	_orb_style.border_color = Color(1, 0.93, 0.7, 1)
	_orb_style.set_border_width_all(1)
	_orb_style.set_corner_radius_all(100)


func _node_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(9)
	return box


func _build_nodes() -> void:
	for definition in SkillTreeData.NODES:
		var id := str(definition["id"])
		var size: Vector2 = definition["size"]
		var locked := bool(definition["locked"])
		var tint: Color = definition["tint"]
		var button := Button.new()
		button.name = "Node_" + id
		button.position = definition["pos"]
		button.size = size
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = str(definition["blurb"])
		button.add_theme_stylebox_override("normal",
				_style_locked if locked else _style_base)
		button.add_theme_stylebox_override("hover", _style_hover)
		button.add_theme_stylebox_override("pressed", _style_hover)
		button.pressed.connect(spend.bind(id))
		node_layer.add_child(button)
		button.size = size  # the container may not be laid out yet
		var chip := Panel.new()
		chip.position = Vector2(size.x * 0.5 - 22.0, 8.0)
		chip.size = Vector2(44, 44)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var chip_style := StyleBoxFlat.new()
		chip_style.bg_color = tint.darkened(0.45)
		chip_style.border_color = GOLD if not locked else Color(0.45, 0.46, 0.5)
		chip_style.set_border_width_all(1)
		chip_style.set_corner_radius_all(8)
		chip.add_theme_stylebox_override("panel", chip_style)
		button.add_child(chip)
		var icon = SKILL_ICON.new()
		icon.kind = str(definition["kind"])
		icon.tint = CREAM if not locked else Color(0.66, 0.68, 0.72)
		icon.position = Vector2(6, 6)
		icon.size = Vector2(32, 32)
		chip.add_child(icon)
		var name_label := Label.new()
		name_label.text = str(definition["name"])
		name_label.position = Vector2(4, 54)
		name_label.size = Vector2(size.x - 8, 26)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", CREAM)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(name_label)
		var rank_label := Label.new()
		rank_label.position = Vector2(4, 80)
		rank_label.size = Vector2(size.x - 8, 22)
		rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_label.add_theme_font_size_override("font_size", 12)
		rank_label.add_theme_color_override("font_color", GOLD_BRIGHT)
		rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(rank_label)
		if locked:
			var lock = SKILL_ICON.new()
			lock.kind = "lock"
			lock.tint = Color(0.85, 0.85, 0.9)
			lock.position = Vector2(size.x - 26.0, 6.0)
			lock.size = Vector2(20, 20)
			button.add_child(lock)
		buttons[id] = button
		rank_labels[id] = rank_label
