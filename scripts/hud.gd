extends Control
## Exploration HUD in the concept-image-6 language: party frames top-left, the
## Combatant objective bar (one segment per wave plus the run timer)
## top-centre, stat bars bottom-left, an icon hotbar bottom-centre, scoreboard,
## minimap top-right and the lock-on reticle.
##
## The party frames and hotbar are built here rather than in the scene so their
## repeated rows share one definition each.

const CREST := preload("res://scripts/heraldic_crest.gd")
const SKILL_ICON := preload("res://scripts/skill_icon.gd")

const MINIMAP_SIZE := 184.0
const WORLD_HALF := 60.0
const SLOT_COUNT := 5

const GOLD := Color(0.85, 0.66, 0.2)
const CREAM := Color(0.95, 0.91, 0.82)
const DIM := Color(0.62, 0.64, 0.7)

## Party roster: the champion's row, then the cleric (see set_companion).
const PARTY := [
	{"name": "Champion", "role": ""},
	{"name": "Maelis Orr", "role": "Cleric"},
]

## Skill name -> drawn icon kind (see scripts/skill_icon.gd).
const SKILL_ICONS := {
	"Cleave": "cleave",
	"Second Wind": "wind",
	"Power Shot": "bow",
	"Tumble": "dash",
}

var player = null  # the player scene root; untyped so hp/stamina/lock fields resolve
var companion = null  # the cleric; untyped so her health fields resolve

@onready var hp_bar: ProgressBar = %HPBar
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var poise_bar: ProgressBar = %PoiseBar
@onready var score_label: Label = %ScoreLabel
@onready var zone_label: Label = %ZoneLabel
@onready var reticle: Control = %Reticle
@onready var minimap_player: Control = %MinimapPlayer
@onready var damage_flash: ColorRect = %DamageFlash
@onready var class_label: Label = %ClassLabel
@onready var level_label: Label = %LevelLabel
@onready var hint_label: Label = %Hint
@onready var wave_label: Label = %WaveLabel
@onready var objective_panel: Control = %Objective
@onready var timer_label: Label = %TimerLabel
@onready var segments_box: HBoxContainer = %Segments
@onready var party_box: VBoxContainer = %PartyFrames
@onready var results_panel: Control = %ResultsPanel
@onready var results_title: Label = %ResultsTitle
@onready var results_body: Label = %ResultsBody
@onready var hotbar: HBoxContainer = $Hotbar

# Hotbar slots: panel, drawn icon, skill name and key caption, in slot order.
var slot_panels: Array = []
var slot_icons: Array = []
var slot_names: Array = []
var slot_keys: Array = []

# Party frames: champion first, then the cleric.
var party_names: Array = []
var party_roles: Array = []
var party_bars: Array = []

# Objective bar: one segment per wave, `objective_filled` of them lit.
var objective_segments: Array = []
var objective_filled := 0

var _seg_empty: StyleBoxFlat = null
var _seg_lit: StyleBoxFlat = null
var _flash_tween: Tween = null
var _results_tween: Tween = null


func _ready() -> void:
	_build_hotbar()
	_build_party()
	objective_panel.visible = false


func set_class(definition: Dictionary) -> void:
	## Class name above the skill bar plus the class's skill names and icons;
	## slots the class has not unlocked yet stay locked (dimmed, padlock). The
	## controls hint swaps for ranged classes (bow shots instead of combo).
	class_label.text = str(definition.get("name", "")).to_upper()
	if ClassKit.is_ranged(str(definition.get("id", ""))):
		hint_label.text = "WASD move    Mouse camera    Shift sprint    Space jump    " \
				+ "Q lock-on    LMB shoot    1 Power Shot    2 Tumble    Esc menu"
	else:
		hint_label.text = "WASD move    Mouse camera    Shift sprint    Space jump    " \
				+ "Q lock-on    LMB attack combo    1 Cleave    2 Second Wind    Esc menu"
	if not party_names.is_empty():
		party_names[0].text = str(definition.get("name", "Champion"))
		party_roles[0].text = str(definition.get("role", ""))
	var skills: Array = ClassKit.skill_names(str(definition.get("id", "")))
	for i in slot_names.size():
		var unlocked := i < skills.size()
		slot_names[i].text = str(skills[i]) if unlocked else "locked"
		slot_names[i].modulate = Color(0.92, 0.9, 0.8, 1) if unlocked \
				else Color(0.5, 0.52, 0.58, 0.85)
		slot_keys[i].text = str(i + 1) if unlocked else "–"
		slot_panels[i].modulate = Color.WHITE if unlocked \
				else Color(0.5, 0.52, 0.58, 0.7)
		var icon = slot_icons[i]
		if unlocked:
			icon.set_kind(str(SKILL_ICONS.get(skills[i], "swords")))
			icon.set_tint(Color(0.97, 0.87, 0.6))
		else:
			icon.set_kind("lock")
			icon.set_tint(Color(0.55, 0.57, 0.63))


## Hand the HUD the live cleric so her party frame reads real health and state.
func set_companion(node) -> void:
	companion = node
	_update_party()


## The champion's level, beside the class name above the hotbar.
func set_level(value: int) -> void:
	level_label.text = "Lv %d" % value


func set_score(kills: int, deaths: int) -> void:
	score_label.text = "Kills %d    Deaths %d" % [kills, deaths]


func set_zone(zone_text: String) -> void:
	zone_label.text = zone_text


func set_wave(wave: int, max_wave: int) -> void:
	## Objective bar under the scoreboard: one segment per wave, lit up to the
	## current wave, plus the wave ticker. Hidden outside the arena.
	objective_panel.visible = wave > 0
	wave_label.visible = wave > 0
	if wave <= 0:
		objective_filled = 0
		timer_label.text = "0:00"
		_apply_segments()
		return
	wave_label.text = "Wave %d / %d" % [wave, max_wave]
	objective_filled = clampi(wave, 0, max_wave)
	_ensure_segments(max_wave)
	_apply_segments()
	if wave == 1:
		timer_label.text = "0:00"


func set_elapsed(seconds: float) -> void:
	var whole := int(seconds)
	timer_label.text = "%d:%02d" % [int(whole / 60.0), whole % 60]


func show_results(title: String, body: String, duration: float = 4.0) -> void:
	## Loop-results panel: wave cleared / arena cleared / fallen.
	_kill_results_tween()
	results_title.text = title
	results_body.text = body
	results_panel.visible = true
	results_panel.modulate.a = 0.0
	_results_tween = create_tween()
	_results_tween.tween_property(results_panel, "modulate:a", 1.0, 0.25)
	_results_tween.tween_interval(duration)
	_results_tween.tween_property(results_panel, "modulate:a", 0.0, 0.35)
	_results_tween.tween_callback(_dismiss_results)


func hide_results() -> void:
	_kill_results_tween()
	_dismiss_results()


func on_player_damaged(_hp: float, _max_hp: float, _poise: float) -> void:
	## Red full-screen flash for incoming damage and death.
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	damage_flash.color = Color(0.75, 0.12, 0.1, 0.42)
	_flash_tween = create_tween()
	_flash_tween.tween_property(damage_flash, "color:a", 0.0, 0.45)


func _build_hotbar() -> void:
	## Five slots from one loop: panel, drawn icon, skill name and key caption.
	## set_class fills the class's skills; the rest keep the padlock.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.08, 0.12, 0.92)
	style.border_color = Color(0.85, 0.66, 0.2, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	for i in SLOT_COUNT:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(64, 64)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", style)
		hotbar.add_child(panel)
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 0)
		panel.add_child(box)
		var icon = SKILL_ICON.new()
		icon.custom_minimum_size = Vector2(0, 28)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.set_kind("lock")
		icon.set_tint(Color(0.55, 0.57, 0.63))
		box.add_child(icon)
		var name_label := _label(9, Color(0.92, 0.9, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
		name_label.text = "locked"
		box.add_child(name_label)
		var key_label := _label(10, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		key_label.text = "–"
		box.add_child(key_label)
		slot_panels.append(panel)
		slot_icons.append(icon)
		slot_names.append(name_label)
		slot_keys.append(key_label)


func _label(font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _build_party() -> void:
	## Two rows, each a crest, name + role and a slim health bar. The rows share
	## one style each; the bars are fed live in _update_party.
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.055, 0.065, 0.105, 0.88)
	frame_style.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.4)
	frame_style.set_border_width_all(1)
	frame_style.set_corner_radius_all(6)
	frame_style.content_margin_left = 8
	frame_style.content_margin_right = 10
	frame_style.content_margin_top = 6
	frame_style.content_margin_bottom = 6
	var bar_back := StyleBoxFlat.new()
	bar_back.bg_color = Color(0.05, 0.05, 0.08, 0.85)
	bar_back.set_corner_radius_all(3)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.35, 0.78, 0.38)
	bar_fill.set_corner_radius_all(3)
	for entry in PARTY:
		var frame := PanelContainer.new()
		frame.custom_minimum_size = Vector2(300, 66)
		frame.add_theme_stylebox_override("panel", frame_style)
		party_box.add_child(frame)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		frame.add_child(row)
		var crest = CREST.new()
		crest.custom_minimum_size = Vector2(30, 30)
		crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(crest)
		var stack := VBoxContainer.new()
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_theme_constant_override("separation", 1)
		row.add_child(stack)
		var name_label := _label(14, CREAM)
		name_label.text = str(entry["name"])
		stack.add_child(name_label)
		var role_label := _label(11, DIM)
		role_label.text = str(entry["role"])
		stack.add_child(role_label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 8)
		bar.show_percentage = false
		bar.max_value = 100.0
		bar.value = 100.0
		bar.add_theme_stylebox_override("background", bar_back)
		bar.add_theme_stylebox_override("fill", bar_fill)
		stack.add_child(bar)
		party_names.append(name_label)
		party_roles.append(role_label)
		party_bars.append(bar)


func _update_party() -> void:
	if player != null and not party_bars.is_empty():
		party_bars[0].max_value = player.max_hp
		party_bars[0].value = player.hp
	if companion == null or not is_instance_valid(companion) or party_bars.size() < 2:
		return
	party_names[1].text = str(companion.party_name)
	var state := "In the square"
	if companion.is_downed:
		state = "Downed"
	elif companion.recruited:
		state = "Following"
	party_roles[1].text = "%s  ·  %s" % [companion.party_role, state]
	party_bars[1].max_value = companion.max_hp
	party_bars[1].value = companion.hp
	party_bars[1].modulate = Color(0.55, 0.57, 0.62) \
			if (not companion.recruited or companion.is_downed) else Color.WHITE


func _update_slot(index: int, cooldown: float) -> void:
	## Live cooldown readout: countdown on the key, dimmed panel while recharging.
	if cooldown > 0.0:
		slot_keys[index].text = str(ceili(cooldown))
		slot_panels[index].modulate = Color(0.55, 0.55, 0.6, 0.95)
	else:
		slot_keys[index].text = str(index + 1)
		slot_panels[index].modulate = Color.WHITE


func _ensure_segments(count: int) -> void:
	if objective_segments.size() == count:
		return
	for child in segments_box.get_children():
		segments_box.remove_child(child)
		child.queue_free()
	objective_segments.clear()
	if _seg_empty == null:
		_seg_empty = StyleBoxFlat.new()
		_seg_empty.bg_color = Color(0.12, 0.13, 0.17, 0.95)
		_seg_empty.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.35)
		_seg_empty.set_border_width_all(1)
		_seg_empty.set_corner_radius_all(3)
		_seg_lit = StyleBoxFlat.new()
		_seg_lit.bg_color = GOLD
		_seg_lit.set_corner_radius_all(3)
	for i in count:
		var segment := Panel.new()
		segment.custom_minimum_size = Vector2(0, 10)
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		segments_box.add_child(segment)
		objective_segments.append(segment)


func _apply_segments() -> void:
	for i in objective_segments.size():
		objective_segments[i].add_theme_stylebox_override("panel",
				_seg_lit if i < objective_filled else _seg_empty)


func _kill_results_tween() -> void:
	if _results_tween != null and _results_tween.is_valid():
		_results_tween.kill()
	_results_tween = null


func _dismiss_results() -> void:
	results_panel.visible = false
	results_panel.modulate.a = 0.0


func _process(_delta: float) -> void:
	if player == null:
		return
	_update_party()
	_update_hotbar()
	_update_minimap()
	# Skill-tree ranks raise the ceilings, so the bars follow the player.
	hp_bar.max_value = player.max_hp
	stamina_bar.max_value = player.max_stamina
	poise_bar.max_value = player.max_poise
	hp_bar.value = player.hp
	stamina_bar.value = player.stamina
	poise_bar.value = player.poise


func _update_hotbar() -> void:
	reticle.visible = player.locked_target != null and is_instance_valid(player.locked_target)
	# Skill cooldowns on hotbar slots 1 (offense) and 2 (utility).
	_update_slot(0, player.skill1_cd)
	_update_slot(1, player.skill2_cd)


func _update_minimap() -> void:
	# World (-60..60) maps onto the 184 px panel, north (-Z) up.
	var scale_px := MINIMAP_SIZE / (WORLD_HALF * 2.0)
	minimap_player.position = Vector2(
			(player.global_position.x + WORLD_HALF) * scale_px - 5.0,
			(player.global_position.z + WORLD_HALF) * scale_px - 5.0)
	minimap_player.rotation = -player.rotation.y
