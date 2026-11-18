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

# Hotbar slots: key caption, skill name and the panel that dims on cooldown.
var slot_keys: Array = []
var slot_names: Array = []
var slot_panels: Array = []

var _flash_tween: Tween = null
var _results_tween: Tween = null


func _ready() -> void:
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
				+ "Q lock-on    LMB shoot    1 Power Shot    2 Tumble    Esc menu"
	else:
		hint_label.text = "WASD move    Mouse camera    Shift sprint    Space jump    " \
				+ "Q lock-on    LMB attack combo    1 Cleave    2 Second Wind    Esc menu"
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
	reticle.visible = player.locked_target != null and is_instance_valid(player.locked_target)

	# Fighter skill cooldowns on hotbar slots 1 (Cleave) and 2 (Second Wind).
	_update_slot(0, player.skill1_cd, "1")
	_update_slot(1, player.skill2_cd, "2")

	# Minimap: world (-60..60) maps onto the 184 px panel, north (-Z) up.
	var scale_px := MINIMAP_SIZE / (WORLD_HALF * 2.0)
	var px: float = (player.global_position.x + WORLD_HALF) * scale_px
	var py: float = (player.global_position.z + WORLD_HALF) * scale_px
	minimap_player.position = Vector2(px - 5.0, py - 5.0)
	minimap_player.rotation = -player.rotation.y
