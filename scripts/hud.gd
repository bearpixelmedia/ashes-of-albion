extends Control
## Exploration HUD: stat bars bottom-left, class skill bar bottom-center,
## scoreboard top-center, minimap top-right, lock-on reticle center.

const MINIMAP_SIZE := 184.0
const WORLD_HALF := 60.0

var player = null  # the player scene root; untyped so hp/stamina/lock fields resolve

@onready var hp_bar: ProgressBar = %HPBar
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var poise_bar: ProgressBar = %PoiseBar
@onready var score_label: Label = %ScoreLabel
@onready var zone_label: Label = %ZoneLabel
@onready var reticle: Control = %Reticle
@onready var minimap_player: Control = %MinimapPlayer
@onready var damage_flash: ColorRect = %DamageFlash
@onready var class_label: Label = %ClassLabel
@onready var hint_label: Label = %Hint
@onready var wave_label: Label = %WaveLabel
@onready var results_panel: Control = %ResultsPanel
@onready var results_title: Label = %ResultsTitle
@onready var results_body: Label = %ResultsBody
@onready var target_frame: Control = %TargetFrame
@onready var target_flag_label: Label = %TargetFlagLabel
@onready var target_name_label: Label = %TargetNameLabel
@onready var target_hp_bar: ProgressBar = %TargetHPBar
@onready var target_hp_text: Label = %TargetHPText
@onready var timer_row: Control = %TimerRow
@onready var timer_label: Label = %TimerLabel

# Hotbar slots: key caption, skill name and the panel that dims on cooldown.
var slot_keys: Array = []
var slot_names: Array = []
var slot_panels: Array = []

var _flash_tween: Tween = null
var _results_tween: Tween = null
# Target frame + run timer state: only restyle/relabel when the value changes.
var _target_fill: StyleBoxFlat = null
var _target_flag := ""
var _timer_second := -1


func _ready() -> void:
	_target_fill = StyleBoxFlat.new()
	_target_fill.bg_color = CombatFlags.color(CombatFlags.NEUTRAL)
	target_hp_bar.add_theme_stylebox_override("fill", _target_fill)
	for i in 5:
		var slot_path := "Hotbar/Slot%d" % (i + 1)
		slot_panels.append(get_node(slot_path))
		slot_keys.append(get_node(slot_path + "/VBox/Key"))
		slot_names.append(get_node(slot_path + "/VBox/Name"))


func set_class(definition: Dictionary) -> void:
	## Class name above the skill bar plus the class's skill names; slots the
	## class has not unlocked yet stay locked (dimmed, "locked" caption). The
	## controls hint swaps for ranged classes (bow shots instead of combo).
	class_label.text = str(definition.get("name", "")).to_upper()
	if ClassKit.is_ranged(str(definition.get("id", ""))):
		hint_label.text = "WASD move    Mouse camera    Shift sprint    Space jump    " \
				+ "Q lock-on    LMB shoot    1 Power Shot    2 Tumble    Esc mouse"
	else:
		hint_label.text = "WASD move    Mouse camera    Shift sprint    Space jump    " \
				+ "Q lock-on    LMB attack combo    1 Cleave    2 Second Wind    Esc mouse"
	var skills: Array = ClassKit.skill_names(str(definition.get("id", "")))
	for i in slot_names.size():
		var unlocked := i < skills.size()
		slot_names[i].text = str(skills[i]) if unlocked else "locked"
		slot_names[i].modulate = Color(0.92, 0.9, 0.8, 1) if unlocked \
				else Color(0.5, 0.52, 0.58, 0.85)
		slot_keys[i].text = str(i + 1) if unlocked else "–"
		slot_panels[i].modulate = Color.WHITE if unlocked \
				else Color(0.5, 0.52, 0.58, 0.7)


func _update_slot(index: int, cooldown: float, key_text: String) -> void:
	## Live cooldown readout for an unlocked slot: countdown on the key,
	## dimmed panel while the skill is recharging.
	if cooldown > 0.0:
		slot_keys[index].text = str(ceili(cooldown))
		slot_panels[index].modulate = Color(0.55, 0.55, 0.6, 0.95)
	else:
		slot_keys[index].text = key_text
		slot_panels[index].modulate = Color.WHITE


func set_score(kills: int, deaths: int) -> void:
	score_label.text = "Kills %d    Deaths %d" % [kills, deaths]


func set_zone(zone_text: String) -> void:
	zone_label.text = zone_text


func set_wave(wave: int, max_wave: int) -> void:
	## Wave counter under the scoreboard; hidden outside the arena.
	if wave <= 0:
		wave_label.visible = false
		return
	wave_label.visible = true
	wave_label.text = "Wave %d / %d" % [wave, max_wave]


## Arena run timer (concept: hourglass beside the target frame). main.gd feeds
## the encounter clock every frame; the label only rewrites once a second.
func set_timer(seconds: float, active: bool) -> void:
	timer_row.visible = active
	if not active:
		_timer_second = -1
		return
	var whole := int(seconds)
	if whole == _timer_second:
		return
	_timer_second = whole
	timer_label.text = "%02d:%02d" % [int(whole / 60), whole % 60]


## Top-centre target frame for whatever the player has locked on: the flag
## (Ally / Combatant / Corrupted / Neutral), the target's name and a segmented
## health bar in the flag's colour.
func _update_target_frame() -> void:
	var target: Node = player.locked_target
	if target == null or not is_instance_valid(target) or _is_down(target):
		target_frame.visible = false
		return
	target_frame.visible = true

	var flag := CombatFlags.NEUTRAL
	if target.has_method("get_combat_flag"):
		flag = CombatFlags.normalize(str(target.call("get_combat_flag")))
	if flag != _target_flag:
		_target_flag = flag
		var tint := CombatFlags.color(flag)
		target_flag_label.text = CombatFlags.label(flag).to_upper()
		target_flag_label.add_theme_color_override("font_color", tint)
		target_name_label.add_theme_color_override("font_color",
				tint.lerp(Color(0.95, 0.93, 0.86, 1.0), 0.55))
		_target_fill.bg_color = tint

	var target_name := str(target.name)
	if target.has_method("get_combat_name"):
		target_name = str(target.call("get_combat_name"))
	if target_name_label.text != target_name:
		target_name_label.text = target_name

	var hp_var: Variant = target.get("hp")
	var max_var: Variant = target.get("max_hp")
	var hp_value := float(hp_var) if hp_var != null else 0.0
	var max_value := float(max_var) if max_var != null else maxf(hp_value, 1.0)
	max_value = maxf(max_value, 1.0)
	target_hp_bar.max_value = max_value
	target_hp_bar.value = hp_value
	var hp_text := "%d / %d" % [int(round(hp_value)), int(round(max_value))]
	if target_hp_text.text != hp_text:
		target_hp_text.text = hp_text


## Same "is it already defeated" read the player uses for cleave arcs.
func _is_down(target: Node) -> bool:
	var defeated: Variant = target.get("is_defeated")
	if defeated != null:
		return bool(defeated)
	var state_value: Variant = target.get("state")
	if state_value != null:
		return int(state_value) == 4  # foe.gd State.DOWN
	return false


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
	hp_bar.value = player.hp
	stamina_bar.value = player.stamina
	poise_bar.value = player.poise
	reticle.visible = player.locked_target != null and is_instance_valid(player.locked_target)
	_update_target_frame()

	# Fighter skill cooldowns on hotbar slots 1 (Cleave) and 2 (Second Wind).
	_update_slot(0, player.skill1_cd, "1")
	_update_slot(1, player.skill2_cd, "2")

	# Minimap: world (-60..60) maps onto the 184 px panel, north (-Z) up.
	var scale_px := MINIMAP_SIZE / (WORLD_HALF * 2.0)
	var px: float = (player.global_position.x + WORLD_HALF) * scale_px
	var py: float = (player.global_position.z + WORLD_HALF) * scale_px
	minimap_player.position = Vector2(px - 5.0, py - 5.0)
	minimap_player.rotation = -player.rotation.y
