class_name CombatFlags
## Combat flagging (concept image: the combat HUD over the arena brawl). Every
## combat actor carries one flag - Ally, Combatant, Corrupted or Neutral - and
## the same flag drives the billboarded chip above its head and the HUD target
## frame, so a unit's allegiance reads identically in the world and in the UI.

const ALLY := "ally"
const COMBATANT := "combatant"
const CORRUPTED := "corrupted"
const NEUTRAL := "neutral"

## Chip label + colour per flag. Combatant purple and Corrupted crimson follow
## the concept; Ally green and the neutral grey complete the vocabulary.
const FLAGS := {
	ALLY: {"label": "Ally", "color": Color(0.42, 0.82, 0.38)},
	COMBATANT: {"label": "Combatant", "color": Color(0.72, 0.44, 0.98)},
	CORRUPTED: {"label": "Corrupted", "color": Color(0.86, 0.22, 0.24)},
	NEUTRAL: {"label": "Neutral", "color": Color(0.74, 0.76, 0.8)},
}

const PLATE_COLOR := Color(0.055, 0.06, 0.1, 0.92)
const CHIP_HEIGHT := 0.3


## Unknown flag ids fall back to Neutral so a chip always reads something.
static func normalize(flag: String) -> String:
	var key := flag.strip_edges().to_lower()
	return key if FLAGS.has(key) else NEUTRAL


static func label(flag: String) -> String:
	return str(FLAGS[normalize(flag)]["label"])


static func color(flag: String) -> Color:
	return FLAGS[normalize(flag)]["color"]


## Combatants and corrupted units are the flags a player may strike.
static func is_hostile(flag: String) -> bool:
	var key := normalize(flag)
	return key == COMBATANT or key == CORRUPTED


## Build the concept chip above an actor: a dark plate with a flag-coloured
## border, the flag label and a downward chevron. Returns the chip root so the
## actor can hide it when it falls.
static func attach_chip(actor: Node3D, flag: String, height: float) -> Node3D:
	var key := normalize(flag)
	var tint := color(key)
	var text := label(key)
	var width := maxf(0.95, text.length() * 0.095 + 0.5)

	var chip := Node3D.new()
	chip.name = "FlagChip"
	chip.position = Vector3(0, height, 0)
	actor.add_child(chip)

	# Border sits just behind the plate; both billboard toward the camera.
	chip.add_child(_quad(Vector2(width + 0.06, CHIP_HEIGHT + 0.06), tint, 0.012, -1))
	chip.add_child(_quad(Vector2(width, CHIP_HEIGHT), PLATE_COLOR, 0.0, 0))

	var label_node := Label3D.new()
	label_node.name = "FlagLabel"
	label_node.text = text
	label_node.font_size = 44
	label_node.outline_size = 0
	label_node.modulate = tint
	label_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Draw the text after the transparent plate whatever the billboard facing
	# does with the local Z offset, or the plate hides it.
	label_node.position = Vector3(0, 0, -0.03)
	label_node.render_priority = 3
	chip.add_child(label_node)

	chip.add_child(_chevron(tint, -CHIP_HEIGHT * 0.5 - 0.13))
	return chip


static func _quad(size: Vector2, tint: Color, z: float, priority: int) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = "Border" if priority < 0 else "Plate"
	node.mesh = mesh
	node.material_override = _billboard_material(tint, priority)
	node.position = Vector3(0, 0, z)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## The tag's downward chevron: one flat triangle, no glyph/font dependency.
static func _chevron(tint: Color, y: float) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.13, 0.055, 0.0),
		Vector3(0.13, 0.055, 0.0),
		Vector3(0.0, -0.075, 0.0),
	])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = "Chevron"
	node.mesh = mesh
	node.material_override = _billboard_material(tint, 0)
	node.position = Vector3(0, y, 0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _billboard_material(tint: Color, priority: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = tint
	mat.render_priority = priority
	return mat
