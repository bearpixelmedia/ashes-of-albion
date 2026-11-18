class_name CombatFlags
## Combat flagging (concept image 4): every arena actor carries one flag -
## Ally, Combatant or Neutral - and the same flag drives the billboarded chip
## over its head and the HUD target frame. Unknown flags read as Neutral.

const ALLY := "ally"
const COMBATANT := "combatant"
const NEUTRAL := "neutral"

const FLAGS := {
	ALLY: {"label": "Ally", "color": Color(0.42, 0.82, 0.38)},
	COMBATANT: {"label": "Combatant", "color": Color(0.72, 0.44, 0.98)},
	NEUTRAL: {"label": "Neutral", "color": Color(0.74, 0.76, 0.8)},
}

const PLATE_COLOR := Color(0.055, 0.06, 0.1, 0.92)
const PLATE_HEIGHT := 0.3


static func label(flag: String) -> String:
	var entry: Dictionary = FLAGS.get(flag, FLAGS[NEUTRAL])
	return str(entry["label"])


static func color(flag: String) -> Color:
	var entry: Dictionary = FLAGS.get(flag, FLAGS[NEUTRAL])
	return entry["color"]


## The flag an actor carries (its `combat_flag`), or "" when it has none.
static func flag_of(actor: Node) -> String:
	var flag: Variant = actor.get("combat_flag")
	return str(flag) if flag != null else ""


## The name an actor advertises (its `combat_name`), else its node name.
static func name_of(actor: Node) -> String:
	var display := str(actor.get("combat_name"))
	return display if not display.is_empty() else str(actor.name)


## The concept's floating tag: a dark plate with a flag-coloured border and the
## flag label, billboarded above the actor. Returns the chip so the actor can
## hide it when it falls.
static func attach_chip(actor: Node3D, flag: String, height: float) -> Node3D:
	var tint := color(flag)
	var text := label(flag)
	var width := maxf(0.95, text.length() * 0.095 + 0.5)

	var chip := Node3D.new()
	chip.name = "FlagChip"
	chip.position = Vector3(0, height, 0)
	actor.add_child(chip)
	chip.add_child(_plate(Vector2(width + 0.06, PLATE_HEIGHT + 0.06), tint, 0.012, -1))
	chip.add_child(_plate(Vector2(width, PLATE_HEIGHT), PLATE_COLOR, 0.0, 0))

	var label_node := Label3D.new()
	label_node.name = "FlagLabel"
	label_node.text = text
	label_node.font_size = 44
	label_node.modulate = tint
	label_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# The plate is nearer than the text in depth sorting; draw the text last.
	label_node.position = Vector3(0, 0, -0.03)
	label_node.render_priority = 3
	chip.add_child(label_node)
	return chip


static func _plate(size: Vector2, tint: Color, z: float, priority: int) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = _billboard_material(tint, priority)
	node.position = Vector3(0, 0, z)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _billboard_material(tint: Color, priority: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = tint
	material.render_priority = priority
	return material
