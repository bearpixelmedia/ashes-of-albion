class_name SkillTreeData
## The Fighter Skill Tree from concept image 1: Swordcraft splits into an
## Offensive and a Defensive form, each with ranked nodes. Ranks live in a
## static table so they survive scene changes, exactly like ClassKit.selected;
## apply_to() pushes them onto the live player kit.
##
## Cleave and Second Wind already exist in the kit, so their branches change
## real numbers; the other ranks are the bonuses their skills will use once
## those skills are built.

const BASE_CLEAVE_DAMAGE := 45.0
const CLEAVE_PER_RANK := 6.0
const OFFENSIVE_PER_RANK := 3.0
const BASE_CLEAVE_RANGE := 4.5
const SUNDER_PER_RANK := 0.25
const BASE_WIND_HEAL := 35.0
const WIND_PER_RANK := 8.0
const DEFENSIVE_PER_RANK := 4.0
const BASE_MAX_HP := 100.0
const FORTIFY_PER_RANK := 5.0
const BASE_MAX_POISE := 100.0
const GUARD_PER_RANK := 3.0

## A level-12 champion with six ranks already committed and two points in
## hand: the state the concept art shows. Progression.points_total() grows
## this pool by one per level above 12.
const POINTS_TOTAL := Progression.BASE_POINTS
const START_RANKS := {
	"offensive": 2, "defensive": 1, "cleave": 1, "sunder": 1, "fortify": 1,
}

## Screen layout in the 1600x900 design space. The screen and tree_links.gd
## both build themselves from this table, so adding a node is a data change.
const NODES: Array[Dictionary] = [
	{"id": "swordcraft", "name": "Swordcraft", "kind": "swords", "max": 0,
		"parent": "", "pos": Vector2(660, 132), "size": Vector2(200, 92),
		"tint": Color(0.72, 0.54, 0.2), "locked": false,
		"blurb": "The root of the fighter's craft."},
	{"id": "offensive", "name": "Offensive Form", "kind": "arc", "max": 3,
		"parent": "swordcraft", "pos": Vector2(250, 266), "size": Vector2(190, 112),
		"tint": Color(0.7, 0.22, 0.16), "locked": false,
		"blurb": "+3 Cleave damage per rank."},
	{"id": "defensive", "name": "Defensive Form", "kind": "shield", "max": 3,
		"parent": "swordcraft", "pos": Vector2(830, 266), "size": Vector2(190, 112),
		"tint": Color(0.2, 0.45, 0.26), "locked": false,
		"blurb": "+4 Second Wind healing per rank."},
	{"id": "cleave", "name": "Cleave", "kind": "cleave", "max": 3,
		"parent": "offensive", "pos": Vector2(170, 424), "size": Vector2(190, 112),
		"tint": Color(0.72, 0.2, 0.14), "locked": false,
		"blurb": "+6 Cleave damage per rank."},
	{"id": "sunder", "name": "Sundering Strike", "kind": "sunder", "max": 3,
		"parent": "offensive", "pos": Vector2(400, 424), "size": Vector2(190, 112),
		"tint": Color(0.66, 0.34, 0.14), "locked": false,
		"blurb": "+0.25 m Cleave reach per rank."},
	{"id": "fortify", "name": "Fortify", "kind": "fist", "max": 3,
		"parent": "defensive", "pos": Vector2(790, 424), "size": Vector2(190, 112),
		"tint": Color(0.24, 0.5, 0.28), "locked": false,
		"blurb": "+5 max health per rank."},
	{"id": "guard_stance", "name": "Guard Stance", "kind": "guard", "max": 3,
		"parent": "defensive", "pos": Vector2(1020, 424), "size": Vector2(190, 112),
		"tint": Color(0.25, 0.42, 0.52), "locked": false,
		"blurb": "+3 max poise per rank."},
	{"id": "whirlwind", "name": "Whirlwind", "kind": "whirl", "max": 0,
		"parent": "cleave", "pos": Vector2(170, 582), "size": Vector2(190, 112),
		"tint": Color(0.45, 0.45, 0.5), "locked": true,
		"blurb": "Locked in this build."},
	{"id": "armor_break", "name": "Armor Break", "kind": "sunder", "max": 0,
		"parent": "sunder", "pos": Vector2(400, 582), "size": Vector2(190, 112),
		"tint": Color(0.45, 0.45, 0.5), "locked": true,
		"blurb": "Locked in this build."},
	{"id": "second_wind", "name": "Second Wind", "kind": "wind", "max": 3,
		"parent": "fortify", "pos": Vector2(790, 582), "size": Vector2(190, 112),
		"tint": Color(0.28, 0.52, 0.32), "locked": false,
		"blurb": "+8 Second Wind healing per rank."},
	{"id": "bulwark", "name": "Bulwark", "kind": "tower", "max": 0,
		"parent": "guard_stance", "pos": Vector2(1020, 582), "size": Vector2(190, 112),
		"tint": Color(0.45, 0.45, 0.5), "locked": true,
		"blurb": "Locked in this build."},
]

## Node id -> owned rank. Filled by ensure() so a direct scene run also works.
static var ranks: Dictionary = {}
static var _ready_once := false


## Replace the tree with saved ranks (used by the save file on boot). Unknown
## ids are dropped and every rank is clamped to the node's maximum, so a stale
## or hand-edited save cannot hand out illegal points.
static func load_ranks(saved: Dictionary) -> void:
	_ready_once = true
	ranks = {}
	for definition in NODES:
		var id := str(definition["id"])
		var cap := maxi(int(definition["max"]), 0)
		ranks[id] = clampi(int(saved.get(id, 0)), 0, cap)


static func ensure() -> void:
	if _ready_once:
		return
	_ready_once = true
	reset_to_default()


static func reset_to_default() -> void:
	ranks = START_RANKS.duplicate(true)


static func reset() -> void:
	ranks = {}
	for definition in NODES:
		ranks[definition["id"]] = 0


static func node_by_id(id: String) -> Dictionary:
	for definition in NODES:
		if definition["id"] == id:
			return definition
	return {}


static func rank_of(id: String) -> int:
	ensure()
	return int(ranks.get(id, 0))


static func points_spent() -> int:
	ensure()
	var spent := 0
	for value in ranks.values():
		spent += int(value)
	return spent


static func points_available() -> int:
	return maxi(Progression.points_total() - points_spent(), 0)


static func can_rank(id: String) -> bool:
	ensure()
	var definition := node_by_id(id)
	if definition.is_empty() or bool(definition["locked"]):
		return false
	var max_rank := int(definition["max"])
	if max_rank <= 0 or rank_of(id) >= max_rank:
		return false
	return points_available() > 0


static func add_rank(id: String) -> int:
	if not can_rank(id):
		return rank_of(id)
	var next := rank_of(id) + 1
	ranks[id] = next
	return next


## Push the tree onto a live player. Cleave/Second Wind feed the real kit;
## Fortify and Guard Stance raise the stat ceilings (the HUD follows).
static func apply_to(player) -> void:
	if player == null:
		return
	ensure()
	var cleave := rank_of("cleave")
	var offensive := rank_of("offensive")
	var sunder := rank_of("sunder")
	var wind := rank_of("second_wind")
	var defensive := rank_of("defensive")
	var fortify := rank_of("fortify")
	var guard := rank_of("guard_stance")
	player.cleave_damage = BASE_CLEAVE_DAMAGE + CLEAVE_PER_RANK * cleave \
			+ OFFENSIVE_PER_RANK * offensive
	player.cleave_range = BASE_CLEAVE_RANGE + SUNDER_PER_RANK * sunder
	player.wind_heal = BASE_WIND_HEAL + WIND_PER_RANK * wind \
			+ DEFENSIVE_PER_RANK * defensive
	var previous_max := float(player.get_meta("skill_tree_max_hp", BASE_MAX_HP))
	player.max_hp = BASE_MAX_HP + FORTIFY_PER_RANK * fortify
	player.max_poise = BASE_MAX_POISE + GUARD_PER_RANK * guard
	if player.hp >= previous_max:
		player.hp = player.max_hp  # a champion at full health stays full
	player.hp = minf(player.hp, player.max_hp)
	player.poise = minf(player.poise, player.max_poise)
	player.set_meta("skill_tree_max_hp", player.max_hp)
