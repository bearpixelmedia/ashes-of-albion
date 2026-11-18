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

@onready var player = $Player
@onready var dummy = $TrainingDummy
@onready var warden = $ArenaWarden
@onready var hud = $UI/HUD
@onready var arena_trigger: Area3D = $ArenaTrigger
@onready var foe_container: Node3D = $ArenaFoes

var zone := ZONE_SQUARE
var kills := 0
var deaths := 0
var wave := 0
var arena_time := 0.0
var spawned_foes: Array = []

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
	dummy.reset()
	warden.reset()


## Swap classes at runtime (used by the character-select flow and tests).
func apply_class(id: String) -> void:
	player.setup_class(id)
	hud.set_class(ClassKit.by_id(id))


func _process(delta: float) -> void:
	if _wave_active:
		arena_time += delta
	if _wave_pending > 0.0:
		_wave_pending -= delta
		if _wave_pending <= 0.0:
			_wave_pending = 0.0
			_spawn_wave()
	hud.set_timer(arena_time, _wave_active)


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
	hud.set_score(kills, deaths)
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
func _composition(wave_number: int) -> Array:
	match wave_number:
		2:
			return [
				[HARRIER_SCENE, Vector3(-8.0, 0.9, -33.5)],
				[BULWARK_SCENE, Vector3(6.5, 0.9, -19.0)],
			]
		3:
			return [
				[WARDEN_SCENE, Vector3(0.0, 0.9, -34.0)],
				[HARRIER_SCENE, Vector3(-6.5, 0.9, -19.0)],
				[BULWARK_SCENE, Vector3(6.5, 0.9, -33.5)],
			]
	return []


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


# --- scoreboard ------------------------------------------------------------

func _on_player_died() -> void:
	deaths += 1
	hud.set_score(kills, deaths)
	if _wave_active:
		hud.show_results("Fallen in the Arena", _results_body())
