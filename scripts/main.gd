extends Node3D
## Game manager: owns the square <-> arena transition, the arena wave loop
## (clear every foe -> the next wave spawns), the loop-results panel and the
## scoreboard.

const ZONE_SQUARE := "Town Square"
const ZONE_ARENA := "Combat Arena"
const MAX_WAVE := 3
const WAVE_DELAY := 2.0

const HARRIER_SCENE := preload("res://scenes/harrier.tscn")
const BULWARK_SCENE := preload("res://scenes/bulwark.tscn")
const WARDEN_SCENE := preload("res://scenes/arena_warden.tscn")
const TOWN_HALL_SCENE := preload("res://scenes/town_hall.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/pause_menu.tscn")
const TOWN_HALL_DOOR := Vector3(0, 0, 16.2)
const TOWN_HALL_RANGE := 3.8
## Ashford's home spawn: the hall forecourt a citizen respawns at.
const ASHFORD_HOME := Vector3(0, 0.85, 14.0)
const KILL_REWARD := 10
## Spawn for the extra foe a sealed Military mandate adds to each wave.
const MILITARY_SPAWNS := [Vector3(-9.5, 0.9, -26.5)]

@onready var player = $Player
@onready var dummy = $TrainingDummy
@onready var warden = $ArenaWarden
@onready var hud = $UI/HUD
@onready var arena_trigger: Area3D = $ArenaTrigger
@onready var foe_container: Node3D = $ArenaFoes

var zone := ZONE_SQUARE
var kills := 0
var deaths := 0
var crowns := 0
var wave := 0
var arena_time := 0.0
var spawned_foes: Array = []
var overlay: OverlayPanel = null  # the one open overlay: the Town Hall or the pause menu
var birth_home := Vector3.ZERO  # the spawn the player entered with, before any claim

## The Town Hall while it is the open overlay (the door prompt and tests read it).
var town_hall: Control:
	get:
		if overlay is TownHallPanel:
			return overlay
		return null

var _alive: Array = []
var _wave_active := false
var _wave_pending := 0.0


func _ready() -> void:
	add_to_group("world")
	arena_trigger.body_entered.connect(_on_arena_body_entered)
	arena_trigger.body_exited.connect(_on_arena_body_exited)
	dummy.defeated.connect(_on_foe_defeated.bind(dummy))
	warden.defeated.connect(_on_foe_defeated.bind(warden))
	player.died.connect(_on_player_died)
	player.damaged.connect(hud.on_player_damaged)
	hud.player = player
	player.setup_class(ClassKit.selected)  # the choice made on the select screen
	hud.set_score(kills, deaths)
	hud.set_zone(zone)
	hud.set_wave(0, MAX_WAVE)
	hud.set_class(ClassKit.by_id(player.class_id))
	hud.show_town_hall_prompt(false)
	hud.set_crowns(crowns)
	ElectionKit.ensure_loaded()  # a mayor counted in an earlier session restores their mandate
	TownHallSave.ensure_loaded()
	birth_home = player.home_position
	apply_citizenship_perks()
	apply_mandate()
	dummy.reset()
	warden.reset()


## Swap classes at runtime (used by the character-select flow and tests).
func apply_class(id: String) -> void:
	player.setup_class(id)
	hud.set_class(ClassKit.by_id(id))


## Citizenship perks: a citizen of Ashford respawns at its hall; renouncing
## hands the birth spawn back. The ZOI house flag lives in TownHallSave.
func apply_citizenship_perks() -> void:
	player.set_home(ASHFORD_HOME if TownHallSave.citizen else birth_home)


func _on_citizenship_changed(_citizen: bool) -> void:
	apply_citizenship_perks()


func _process(delta: float) -> void:
	var mend := MandateKit.heal_per_second()
	if mend > 0.0 and not player.is_dead:
		player.hp = minf(player.hp + mend * delta, player.max_hp)
	var near := near_town_hall()  # never runs while an overlay has the tree paused
	hud.show_town_hall_prompt(near)
	if near and Input.is_action_just_pressed("interact"):
		open_town_hall()
	if _wave_active:
		arena_time += delta
	if _wave_pending > 0.0:
		_wave_pending -= delta
		if _wave_pending <= 0.0:
			_wave_pending = 0.0
			_spawn_wave()


func _on_arena_body_entered(body: Node3D) -> void:
	if body != player:
		return
	zone = ZONE_ARENA
	hud.set_zone(zone)
	_start_wave_loop()


func _on_arena_body_exited(body: Node3D) -> void:
	if body != player:
		return
	zone = ZONE_SQUARE
	hud.set_zone(zone)
	_end_wave_loop()


# --- wave loop -------------------------------------------------------------

func _start_wave_loop() -> void:
	_clear_spawned()
	wave = 1
	_wave_active = true
	_wave_pending = 0.0
	arena_time = 0.0
	dummy.reset()  # fresh opponents every entry
	warden.reset()
	_alive = [dummy, warden]
	hud.hide_results()
	hud.set_wave(wave, MAX_WAVE)


func _end_wave_loop() -> void:
	_clear_spawned()
	_alive.clear()
	dummy.reset()  # loop restarts cleanly on the way back
	warden.reset()
	wave = 0
	_wave_active = false
	_wave_pending = 0.0
	hud.hide_results()
	hud.set_wave(0, MAX_WAVE)


func _clear_spawned() -> void:
	for foe in spawned_foes:
		if is_instance_valid(foe):
			foe.queue_free()
	spawned_foes.clear()


func _on_foe_defeated(foe: Node) -> void:
	kills += 1
	crowns += MandateKit.crowns_per_kill(KILL_REWARD)
	hud.set_score(kills, deaths)
	hud.set_crowns(crowns)
	if not _wave_active or zone != ZONE_ARENA:
		return
	_alive.erase(foe)
	if _alive.is_empty():
		_wave_cleared()


func _wave_cleared() -> void:
	if wave >= MAX_WAVE:
		hud.show_results("Arena Cleared", _results_body(), 6.0)
		return
	hud.show_results("Wave %d cleared" % wave, _results_body())
	_wave_pending = WAVE_DELAY


func _spawn_wave() -> void:
	if not _wave_active:
		return
	hud.hide_results()
	_clear_spawned()  # last wave's fallen fade out between waves
	wave += 1
	hud.set_wave(wave, MAX_WAVE)
	for entry in _composition(wave):
		_spawn_foe(entry[0], entry[1])


## Wave table: spawn points sit clear of the pillar, the cover boxes, the
## raised platforms and the torch posts at x = +/-6.5 (see town_layout.gd).
## A sealed Military mandate adds an extra bulwark to every wave.
func _composition(wave_number: int) -> Array:
	var table: Array = []
	match wave_number:
		2:
			table = [
				[HARRIER_SCENE, Vector3(-8.0, 0.9, -33.5)],
				[BULWARK_SCENE, Vector3(6.5, 0.9, -19.0)],
			]
		3:
			table = [
				[WARDEN_SCENE, Vector3(0.0, 0.9, -34.0)],
				[HARRIER_SCENE, Vector3(-6.5, 0.9, -19.0)],
				[BULWARK_SCENE, Vector3(6.5, 0.9, -33.5)],
			]
	if table.is_empty():
		return table
	for i in mini(MandateKit.extra_foes(), MILITARY_SPAWNS.size()):
		table.append([BULWARK_SCENE, MILITARY_SPAWNS[i]])
	return table


func _spawn_foe(scene: PackedScene, pos: Vector3) -> void:
	var foe = scene.instantiate()  # untyped: variant scripts own their members
	foe.position = pos  # set before entering the tree: _ready captures home
	foe_container.add_child(foe)
	foe.defeated.connect(_on_foe_defeated.bind(foe))
	_alive.append(foe)
	spawned_foes.append(foe)


func _results_body() -> String:
	var minutes := int(arena_time) / 60
	var seconds := int(arena_time) % 60
	return "Kills %d    Deaths %d    Time %d:%02d" % [kills, deaths, minutes, seconds]


# --- town hall -------------------------------------------------------------

## Read the sealed ballot into the HUD and the run (cooldowns and waves read
## MandateKit live; healing and crowns are handled here).
func apply_mandate() -> void:
	hud.set_mandate(MandateKit.headline())


func _on_ballot_sealed(_candidate: Dictionary) -> void:
	apply_mandate()


## The southern building is the Town Hall; its door is the interaction point.
func near_town_hall() -> bool:
	if player == null or player.is_dead:
		return false
	var offset: Vector3 = player.global_position - TOWN_HALL_DOOR
	offset.y = 0.0
	return offset.length() <= TOWN_HALL_RANGE


# --- overlays: Town Hall + pause menu ----------------------------------------

## The shared overlay handoff: one overlay at a time, the whole tree paused while
## it is open, and the overlay's `closed` signal as the only way back. Both the
## Town Hall and the pause menu come through here, so neither carries freeze code.
func open_overlay(scene: PackedScene) -> OverlayPanel:
	if overlay != null:
		return null
	var panel := scene.instantiate() as OverlayPanel
	panel.closed.connect(_close_overlay)
	overlay = panel
	$UI.add_child(panel)
	hud.show_town_hall_prompt(false)
	player.velocity = Vector3.ZERO
	get_tree().paused = true
	return panel


## Idempotent so a double Back/Esc cannot resume the world twice.
func _close_overlay() -> void:
	if overlay == null:
		return
	get_tree().paused = false
	overlay.queue_free()
	overlay = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Open the Citizenship & Election panel over the running world.
func open_town_hall() -> void:
	if open_overlay(TOWN_HALL_SCENE) == null:
		return
	var hall := overlay as TownHallPanel
	hall.embedded = true
	hall.ballot_sealed.connect(_on_ballot_sealed)
	hall.citizenship_changed.connect(_on_citizenship_changed)


## Esc in the world: the pause menu (Resume / Settings / Return to Title).
func open_pause_menu() -> void:
	if open_overlay(PAUSE_MENU_SCENE) == null:
		return
	(overlay as PauseMenu).title_requested.connect(_return_to_title)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		open_pause_menu()


func _return_to_title() -> void:
	_close_overlay()
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


# --- scoreboard ------------------------------------------------------------

func _on_player_died() -> void:
	deaths += 1
	hud.set_score(kills, deaths)
	if _wave_active:
		hud.show_results("Fallen in the Arena", _results_body())
