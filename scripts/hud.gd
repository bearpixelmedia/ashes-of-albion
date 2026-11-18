extends Control
## Exploration HUD in the concept-image-6 language: party frames top-left, the
## Combatant objective bar (one segment per wave plus the run timer)
## top-centre, stat bars bottom-left, an icon hotbar bottom-centre, scoreboard,
## minimap top-right and the lock-on reticle.

const CREST := preload("res://scripts/heraldic_crest.gd")

const MINIMAP_SIZE := 184.0
const WORLD_HALF := 60.0

const GOLD := Color(0.85, 0.66, 0.2)
const CREAM := Color(0.95, 0.91, 0.82)
const DIM := Color(0.62, 0.64, 0.7)

## Party roster: the champion's row is live, and the second row is the cleric
## companion once main.gd hands her over (see set_companion).
const PARTY := [
	{"name": "Champion", "role": "", "hp": 1.0, "live": true},
	{"name": "Maelis Orr", "role": "Cleric", "hp": 1.0, "live": false},
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

# Hotbar slots: key caption, skill name, drawn icon and the panel that dims
# on cooldown.
var slot_keys: Array = []
var slot_names: Array = []
var slot_icons: Array = []
var slot_panels: Array = []

# Party frames: champion first, then the placeholder companions.
var party_names: Array = []
var party_roles: Array = []
var party_bars: Array = []

# Objective bar: one segment per wave, `objective_filled` of them lit.
var objective_segments: Array = []
var objective_filled := 0

var _flash_tween: Tween = null
var _results_tween: Tween = null
var _shown_level := -1


func _ready() -> void:
	for i in 5:
		var slot_path := "Hotbar/Slot%d" % (i + 1)
		slot_panels.append(get_node(slot_path))
		slot_icons.append(get_node(slot_path + "/VBox/Icon"))
		slot_keys.append(get_node(slot_path + "/VBox/Key"))
		slot_names.append(get_node(slot_path + "/VBox/Name"))
	_build_party()
	objective_panel.visible = false
	set_level(Progression.level)


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


func _update_slot(index: int, cooldown: float, key_text: String) -> void:
	## Live cooldown readout for an unlocked slot: countdown on the key,
	## dimmed panel while the skill is recharging.
	if cooldown > 0.0:
		slot_keys[index].text = str(ceili(cooldown))
		slot_panels[index].modulate = Color(0.55, 0.55, 0.6, 0.95)
	else:
		slot_keys[index].text = key_text
		slot_panels[index].modulate = Color.WHITE


func _build_party() -> void:
	## Three party frames, each a crest, name + role and a slim health bar.
	for entry in PARTY:
		var frame := PanelContainer.new()
		frame.custom_minimum_size = Vector2(300, 66)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.055, 0.065, 0.105, 0.88)
		style.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.4)
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 8
		style.content_margin_right = 10
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		frame.add_theme_stylebox_override("panel", style)
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
		var name_label := Label.new()
		name_label.text = str(entry["name"])
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", CREAM)
		stack.add_child(name_label)
		var role_label := Label.new()
		role_label.text = str(entry["role"])
		role_label.add_theme_font_size_override("font_size", 11)
		role_label.add_theme_color_override("font_color", DIM)
		stack.add_child(role_label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 8)
		bar.show_percentage = false
		bar.max_value = 100.0
		bar.value = float(entry["hp"]) * 100.0
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0.05, 0.05, 0.08, 0.85)
		back.set_corner_radius_all(3)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.35, 0.78, 0.38)
		fill.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("background", back)
		bar.add_theme_stylebox_override("fill", fill)
		stack.add_child(bar)
		party_box.add_child(frame)
		party_names.append(name_label)
		party_roles.append(role_label)
		party_bars.append(bar)


## The champion's level, beside the class name above the hotbar.
## Hand the HUD the live cleric so her party frame reads real health and state.
func set_companion(node) -> void:
	companion = node
	if node != null and party_names.size() > 1:
		party_names[1].text = str(node.party_name)
		party_roles[1].text = str(node.party_role)


func set_level(value: int) -> void:
	_shown_level = value
	level_label.text = "Lv %d" % value


func set_score(kills: int, deaths: int) -> void:
	score_label.text = "Kills %d    Deaths %d" % [kills, deaths]


func set_zone(zone_text: String) -> void:
	zone_label.text = zone_text


func set_wave(wave: int, max_wave: int) -> void:
	## Objective bar under the scoreboard: one segment per wave, lit up to the
	## current wave, plus the wave ticker. Hidden outside the arena.
	var active := wave > 0
	objective_panel.visible = active
	wave_label.visible = active
	if not active:
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


func _ensure_segments(count: int) -> void:
	if objective_segments.size() == count:
		return
	for child in segments_box.get_children():
		segments_box.remove_child(child)
		child.queue_free()
	objective_segments.clear()
	for i in count:
		var segment := Panel.new()
		segment.custom_minimum_size = Vector2(0, 10)
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		segments_box.add_child(segment)
		objective_segments.append(segment)


func _apply_segments() -> void:
	var empty := StyleBoxFlat.new()
	empty.bg_color = Color(0.12, 0.13, 0.17, 0.95)
	empty.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.35)
	empty.set_border_width_all(1)
	empty.set_corner_radius_all(3)
	var lit := StyleBoxFlat.new()
	lit.bg_color = GOLD
	lit.set_corner_radius_all(3)
	for i in objective_segments.size():
		objective_segments[i].add_theme_stylebox_override("panel",
				lit if i < objective_filled else empty)


func show_results(title: String, body: String, duration: float = 4.0) -> void:
	## Loop-results panel: wave cleared / arena cleared / fallen.
	if _results_tween != null and _results_tween.is_valid():
		_results_tween.kill()
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
	if _results_tween != null and _results_tween.is_valid():
		_results_tween.kill()
	_results_tween = null
	_dismiss_results()


func _dismiss_results() -> void:
	results_panel.visible = false
	results_panel.modulate.a = 0.0


func on_player_damaged(_hp: float, _max_hp: float, _poise: float) -> void:
	## Red full-screen flash for incoming damage and death.
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	damage_flash.color = Color(0.75, 0.12, 0.1, 0.42)
	_flash_tween = create_tween()
	_flash_tween.tween_property(damage_flash, "color:a", 0.0, 0.45)


func _process(_delta: float) -> void:
	if player == null:
		return
	# Skill-tree ranks raise the ceilings, so the bars follow the player.
	hp_bar.max_value = player.max_hp
	stamina_bar.max_value = player.max_stamina
	poise_bar.max_value = player.max_poise
	hp_bar.value = player.hp
	stamina_bar.value = player.stamina
	poise_bar.value = player.poise
	# Level-ups can happen from a kill; keep the readout on the live value.
	if Progression.level != _shown_level:
		set_level(Progression.level)
	# The cleric's frame is live: health, and whether she is following or down.
	if companion != null and is_instance_valid(companion) and party_bars.size() > 1:
		party_bars[1].max_value = companion.max_hp
		party_bars[1].value = companion.hp
		party_names[1].text = str(companion.party_name)
		var state := "In the square"
		if companion.is_downed:
			state = "Downed"
		elif companion.recruited:
			state = "Following"
		party_roles[1].text = "%s  ·  %s" % [companion.party_role, state]
		party_bars[1].modulate = Color(0.55, 0.57, 0.62) \
				if (not companion.recruited or companion.is_downed) else Color.WHITE
	# The champion's party frame mirrors the same live health.
	if not party_bars.is_empty():
		party_bars[0].max_value = player.max_hp
		party_bars[0].value = player.hp
	reticle.visible = player.locked_target != null and is_instance_valid(player.locked_target)

	# Class skill cooldowns on hotbar slots 1 (offense) and 2 (utility).
	_update_slot(0, player.skill1_cd, "1")
	_update_slot(1, player.skill2_cd, "2")

	# Minimap: world (-60..60) maps onto the 184 px panel, north (-Z) up.
	var scale_px := MINIMAP_SIZE / (WORLD_HALF * 2.0)
	var px: float = (player.global_position.x + WORLD_HALF) * scale_px
	var py: float = (player.global_position.z + WORLD_HALF) * scale_px
	minimap_player.position = Vector2(px - 5.0, py - 5.0)
	minimap_player.rotation = -player.rotation.y
