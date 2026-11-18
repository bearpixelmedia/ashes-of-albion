class_name ClassKit
## The eight archetypes from concept images 2/3 (docs/art-direction/concept/
## classes.png, character-select-screen.png): shared roster data for the
## champion lineup, the character-select screen, the HUD skill bar and the
## player's class kit. These are design proposals from the art set, not
## confirmed Ashes of Creation facts. Fighter and Ranger are playable; the
## other six are preview-only for now.

const CEL_SHADER := preload("res://shaders/cel.gdshader")

## Order matches concept image 2/3, left to right. "blurb" is the flavor line
## under each archetype on the character-select screen (concept image 3).
const ARCHETYPES: Array[Dictionary] = [
	{
		"id": "bard", "name": "Bard", "role": "Support",
		"blurb": "Rally with song.", "ranged": false,
		"body": Color(0.14, 0.38, 0.2), "trim": Color(0.6, 0.16, 0.16),
		"head": "feather_hat", "back": "cape", "weapon": "lute",
		"ally": false,
	},
	{
		"id": "cleric", "name": "Cleric", "role": "Healer",
		"blurb": "Mend and protect.", "ranged": false,
		"body": Color(0.92, 0.92, 0.88), "trim": Color(0.16, 0.3, 0.62),
		"head": "hood", "back": "", "weapon": "mace",
		"ally": false,
	},
	{
		"id": "fighter", "name": "Fighter", "role": "Melee",
		"blurb": "Master the blade.", "ranged": false,
		"body": Color(0.6, 0.63, 0.68), "trim": Color(0.55, 0.14, 0.14),
		"head": "helm", "back": "", "weapon": "greatsword",
		"ally": false,
	},
	{
		"id": "mage", "name": "Mage", "role": "Ranged",
		"blurb": "Shape the elements.", "ranged": true,
		"body": Color(0.16, 0.3, 0.66), "trim": Color(0.85, 0.68, 0.25),
		"head": "wide_hat", "back": "", "weapon": "staff",
		"ally": false,
	},
	{
		"id": "ranger", "name": "Ranger", "role": "Ranged",
		"blurb": "Strike from afar.", "ranged": true,
		"body": Color(0.32, 0.5, 0.22), "trim": Color(0.42, 0.3, 0.2),
		"head": "hood", "back": "quiver", "weapon": "bow",
		"ally": false,
	},
	{
		"id": "rogue", "name": "Rogue", "role": "Melee",
		"blurb": "Attack from shadow.", "ranged": false,
		"body": Color(0.26, 0.22, 0.24), "trim": Color(0.55, 0.16, 0.16),
		"head": "hood", "back": "", "weapon": "daggers",
		"ally": false,
	},
	{
		"id": "summoner", "name": "Summoner", "role": "Summoner",
		"blurb": "Call spectral allies.", "ranged": false,
		"body": Color(0.1, 0.42, 0.36), "trim": Color(0.8, 0.64, 0.24),
		"head": "glasses", "back": "", "weapon": "book",
		"ally": true,
	},
	{
		"id": "tank", "name": "Tank", "role": "Tank",
		"blurb": "Hold the line.", "ranged": false,
		"body": Color(0.72, 0.74, 0.78), "trim": Color(0.16, 0.3, 0.62),
		"head": "helm", "back": "", "weapon": "shield",
		"ally": false,
	},
]

## Playable class kits: hotbar skill names per slot. Slots past the end of a
## class's list stay locked on the HUD until that class is implemented.
const SKILLS := {
	"fighter": ["Cleave", "Second Wind"],
	"ranger": ["Power Shot", "Tumble"],
}

const FIGHTER := "fighter"
const RANGER := "ranger"

## Committed by the character-select screen before it loads the world; the
## world reads it in main._ready. Defaults to the fighter for direct runs of
## main.tscn (smoke tests, F6 debugging).
static var selected := "fighter"

static var _material_cache: Dictionary = {}


static func by_id(id: String) -> Dictionary:
	for entry in ARCHETYPES:
		if entry["id"] == id:
			return entry
	return {}


static func by_index(index: int) -> Dictionary:
	if index >= 0 and index < ARCHETYPES.size():
		return ARCHETYPES[index]
	return {}


static func skill_names(class_id: String) -> Array:
	return SKILLS.get(class_id, [])


static func is_playable(id: String) -> bool:
	return SKILLS.has(id)


static func is_ranged(id: String) -> bool:
	return bool(by_id(id).get("ranged", false))


static func index_of(id: String) -> int:
	for i in ARCHETYPES.size():
		if ARCHETYPES[i]["id"] == id:
			return i
	return -1


## Shared cel material for lineup figures: one cached ShaderMaterial per
## (albedo, emission) pair so eight champions cost a handful of materials.
static func make_material(color: Color, emission: Color = Color.BLACK) -> ShaderMaterial:
	var key := "%s|%s" % [color.to_html(), emission.to_html()]
	if _material_cache.has(key):
		return _material_cache[key]
	var material := ShaderMaterial.new()
	material.shader = CEL_SHADER
	material.set_shader_parameter("albedo_color", color)
	material.set_shader_parameter("ambient_floor", 0.26)
	if emission == Color.BLACK:
		material.set_shader_parameter("ambient_emit", 0.16)
	else:
		material.set_shader_parameter("ambient_emit", 0.1)
		material.set_shader_parameter("emission_color", emission)
		material.set_shader_parameter("emission_strength", 1.5)
	_material_cache[key] = material
	return material
