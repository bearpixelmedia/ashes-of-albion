extends Node3D
## One champion of the eight-archetype lineup (concept image 2): a primitive
## figure whose silhouette, colours and weapon prop follow ClassKit's
## definition. Everything is built from engine meshes, so the prototype needs
## no art assets; the figure idles with a gentle bob and a floating nameplate.

@export var archetype_index := 0

# Shared palette for props that recur across the roster.
const FLESH := Color(0.85, 0.68, 0.55)
const ARMOR := Color(0.58, 0.61, 0.66)
const GOLD := Color(0.85, 0.68, 0.25)
const WOOD := Color(0.45, 0.33, 0.2)
const DARK := Color(0.16, 0.15, 0.17)
const WHITE := Color(0.88, 0.88, 0.86)
const PARCHMENT := Color(0.88, 0.84, 0.7)
const LEATHER := Color(0.4, 0.29, 0.2)

var display_name := ""
var role := ""
var weapon_id := ""
var body_color := Color.WHITE
var nameplate: Label3D = null
var ally: Node3D = null

@onready var visual: Node3D = $Visual


func _ready() -> void:
	var definition := ClassKit.by_index(archetype_index)
	if definition.is_empty():
		push_warning("archetype_figure: no archetype at index %d" % archetype_index)
		return
	display_name = str(definition["name"])
	role = str(definition["role"])
	weapon_id = str(definition["weapon"])
	body_color = definition["body"]
	nameplate = $Nameplate
	nameplate.text = "%s\n%s" % [display_name, role]
	_build(definition)
	_idle_sway()


func _build(definition: Dictionary) -> void:
	var trim_color: Color = definition["trim"]
	var body_mat := ClassKit.make_material(body_color)
	var trim_mat := ClassKit.make_material(trim_color)
	var metal_mat := ClassKit.make_material(ARMOR)
	var wood_mat := ClassKit.make_material(WOOD)
	var gold_mat := ClassKit.make_material(GOLD)
	var flesh_mat := ClassKit.make_material(FLESH)

	# Common base: body, front tabard, shoulders, head.
	_mesh(_capsule(0.32, 1.4), body_mat, Vector3(0, 0.7, 0))
	_box(Vector3(0.44, 0.85, 0.06), trim_mat, Vector3(0, 0.85, -0.3))
	_box(Vector3(0.62, 0.16, 0.34), body_mat, Vector3(0, 1.32, 0))
	_mesh(_sphere_mesh(0.21), flesh_mat, Vector3(0, 1.62, 0))

	_build_back(str(definition["back"]), trim_mat, wood_mat)
	_build_head(str(definition["head"]), body_mat, trim_mat, metal_mat, gold_mat)
	_build_weapon(str(definition["weapon"]), metal_mat, wood_mat, gold_mat, trim_mat)
	if bool(definition["ally"]):
		_build_ally()


## Headgear gives each silhouette its concept-image identity.
func _build_head(kind: String, body_mat: Material, trim_mat: Material,
		metal_mat: Material, gold_mat: Material) -> void:
	var dark_mat := ClassKit.make_material(DARK)
	match kind:
		"feather_hat":
			var hat := Node3D.new()
			hat.name = "Hat"
			visual.add_child(hat)
			_cylinder(0.32, 0.32, 0.05, trim_mat, Vector3(0, 1.82, 0), Vector3.ZERO, hat)
			_cylinder(0.17, 0.19, 0.18, trim_mat, Vector3(0, 1.92, 0), Vector3.ZERO, hat)
			_box(Vector3(0.05, 0.34, 0.02), ClassKit.make_material(WHITE),
				Vector3(0.14, 2.08, 0), Vector3(0, 0, -0.5), hat)
		"hood":
			var hood := Node3D.new()
			hood.name = "Hood"
			visual.add_child(hood)
			var cowl := _mesh(_sphere_mesh(0.27), trim_mat, Vector3(0, 1.66, 0.05), Vector3.ZERO, hood)
			cowl.scale = Vector3(1, 1.05, 1.15)
			_box(Vector3(0.56, 0.18, 0.36), trim_mat, Vector3(0, 1.4, 0), Vector3.ZERO, hood)
		"helm":
			var helm := Node3D.new()
			helm.name = "Helm"
			visual.add_child(helm)
			_cylinder(0.22, 0.24, 0.3, metal_mat, Vector3(0, 1.74, 0), Vector3.ZERO, helm)
			_box(Vector3(0.3, 0.07, 0.1), dark_mat, Vector3(0, 1.72, -0.2), Vector3.ZERO, helm)
			_box(Vector3(0.06, 0.18, 0.26), trim_mat, Vector3(0, 1.95, 0.02),
				Vector3(-0.3, 0, 0), helm)
		"wide_hat":
			var hat := Node3D.new()
			hat.name = "WideHat"
			visual.add_child(hat)
			_cylinder(0.46, 0.46, 0.05, body_mat, Vector3(0, 1.84, 0), Vector3.ZERO, hat)
			_cylinder(0.05, 0.27, 0.38, body_mat, Vector3(0, 2.05, 0), Vector3.ZERO, hat)
			_box(Vector3(0.5, 0.04, 0.06), gold_mat, Vector3(0, 1.88, -0.16),
				Vector3(0.1, 0, 0), hat)
		"glasses":
			var glasses := Node3D.new()
			glasses.name = "Glasses"
			visual.add_child(glasses)
			_box(Vector3(0.3, 0.05, 0.05), dark_mat, Vector3(0, 1.66, -0.2),
				Vector3.ZERO, glasses)
		_:
			# Bare head: nothing to add.
			pass


## Back props: the bard's cape and the ranger's quiver.
func _build_back(kind: String, trim_mat: Material, wood_mat: Material) -> void:
	match kind:
		"cape":
			_box(Vector3(0.5, 0.9, 0.05), trim_mat, Vector3(0, 0.9, 0.3))
		"quiver":
			var quiver := Node3D.new()
			quiver.name = "Quiver"
			visual.add_child(quiver)
			_box(Vector3(0.2, 0.62, 0.2), ClassKit.make_material(LEATHER),
				Vector3(0.26, 1.2, 0.3), Vector3(0.25, 0, 0.15), quiver)
			_box(Vector3(0.03, 0.5, 0.03), wood_mat,
				Vector3(0.2, 1.6, 0.36), Vector3(0.25, 0, 0.2), quiver)
			_box(Vector3(0.03, 0.5, 0.03), wood_mat,
				Vector3(0.32, 1.58, 0.3), Vector3(0.25, 0, -0.1), quiver)


## One weapon prop per archetype — the concept image's "one weapon each".
func _build_weapon(weapon: String, metal_mat: Material, wood_mat: Material,
		gold_mat: Material, trim_mat: Material) -> void:
	var pivot := Node3D.new()
	pivot.name = "Weapon"
	visual.add_child(pivot)
	match weapon:
		"lute":
			_box(Vector3(0.36, 0.44, 0.12), wood_mat, Vector3(0.12, 1.0, -0.38),
				Vector3(0, 0, 0.35), pivot)
			_box(Vector3(0.07, 0.5, 0.07), wood_mat, Vector3(0.34, 1.34, -0.38),
				Vector3(0, 0, 0.35), pivot)
			_mesh(_sphere_mesh(0.05), ClassKit.make_material(DARK),
				Vector3(0.06, 0.95, -0.45), Vector3.ZERO, pivot)
		"mace":
			_box(Vector3(0.06, 0.95, 0.06), wood_mat, Vector3(0.46, 1.1, -0.25),
				Vector3.ZERO, pivot)
			_mesh(_sphere_mesh(0.14), gold_mat, Vector3(0.46, 1.66, -0.25), Vector3.ZERO, pivot)
		"greatsword":
			var sword := Node3D.new()
			sword.name = "Greatsword"
			pivot.add_child(sword)
			_box(Vector3(0.13, 1.55, 0.05), metal_mat, Vector3(0.3, 0.85, -0.42),
				Vector3.ZERO, sword)
			_box(Vector3(0.44, 0.08, 0.09), gold_mat, Vector3(0.3, 1.66, -0.42),
				Vector3.ZERO, sword)
			_box(Vector3(0.07, 0.26, 0.07), wood_mat, Vector3(0.3, 1.82, -0.42),
				Vector3.ZERO, sword)
			_mesh(_sphere_mesh(0.06), gold_mat, Vector3(0.3, 1.98, -0.42), Vector3.ZERO, sword)
		"staff":
			_cylinder(0.03, 0.035, 2.1, wood_mat, Vector3(0.46, 1.05, -0.25),
				Vector3.ZERO, pivot)
			_mesh(_sphere_mesh(0.15),
				ClassKit.make_material(Color(0.35, 0.8, 1.0), Color(0.3, 0.75, 1.0)),
				Vector3(0.46, 2.2, -0.25), Vector3.ZERO, pivot)
		"bow":
			_box(Vector3(0.05, 1.5, 0.05), wood_mat, Vector3(-0.48, 1.0, -0.3),
				Vector3(0, 0, 0.14), pivot)
			_box(Vector3(0.012, 1.38, 0.012), ClassKit.make_material(WHITE),
				Vector3(-0.48, 1.0, -0.36), Vector3.ZERO, pivot)
		"daggers":
			for side in [-1.0, 1.0]:
				_box(Vector3(0.04, 0.34, 0.1), metal_mat,
					Vector3(0.44 * side, 0.98, -0.4), Vector3(-0.5, 0, 0), pivot)
				_box(Vector3(0.05, 0.14, 0.05), wood_mat,
					Vector3(0.44 * side, 0.78, -0.33), Vector3(-0.5, 0, 0), pivot)
		"book":
			var book := Node3D.new()
			book.name = "Book"
			pivot.add_child(book)
			_box(Vector3(0.38, 0.06, 0.28), ClassKit.make_material(Color(0.2, 0.34, 0.2)),
				Vector3(0, 1.0, -0.42), Vector3.ZERO, book)
			_box(Vector3(0.3, 0.04, 0.24), ClassKit.make_material(PARCHMENT),
				Vector3(-0.15, 1.06, -0.42), Vector3(0, 0, 0.3), book)
			_box(Vector3(0.3, 0.04, 0.24), ClassKit.make_material(PARCHMENT),
				Vector3(0.15, 1.06, -0.42), Vector3(0, 0, -0.3), book)
			_mesh(_sphere_mesh(0.05),
				ClassKit.make_material(Color(0.3, 0.8, 0.4), Color(0.2, 0.7, 0.3)),
				Vector3(0.3, 0.72, -0.3), Vector3.ZERO, pivot)
			_mesh(_sphere_mesh(0.05),
				ClassKit.make_material(Color(0.8, 0.3, 0.3), Color(0.7, 0.2, 0.2)),
				Vector3(0.4, 0.72, -0.26), Vector3.ZERO, pivot)
		"shield":
			var shield := Node3D.new()
			shield.name = "TowerShield"
			pivot.add_child(shield)
			_box(Vector3(0.58, 1.3, 0.09), trim_mat, Vector3(-0.55, 1.0, -0.32),
				Vector3(0, 0.25, 0), shield)
			_box(Vector3(0.58, 0.1, 0.1), gold_mat, Vector3(-0.55, 1.5, -0.34),
				Vector3(0, 0.25, 0), shield)
			_box(Vector3(0.2, 0.2, 0.1), gold_mat, Vector3(-0.55, 1.05, -0.36),
				Vector3(0, 0.25, 0), shield)


## The summoner's spectral ally, floating beside the shoulder.
func _build_ally() -> void:
	ally = Node3D.new()
	ally.name = "Ally"
	ally.position = Vector3(0.72, 1.9, -0.1)
	visual.add_child(ally)
	var spirit := ClassKit.make_material(Color(0.45, 0.85, 1.0), Color(0.35, 0.8, 1.0))
	_mesh(_sphere_mesh(0.2), spirit, Vector3.ZERO, Vector3.ZERO, ally)
	_cylinder(0.02, 0.1, 0.26, spirit, Vector3(0, -0.03, -0.26),
		Vector3(-PI / 2.0, 0, 0), ally)
	_cylinder(0.0, 0.07, 0.14, spirit, Vector3(-0.08, 0.2, -0.02), Vector3.ZERO, ally)
	_cylinder(0.0, 0.07, 0.14, spirit, Vector3(0.08, 0.2, -0.02), Vector3.ZERO, ally)
	_mesh(_sphere_mesh(0.09), spirit, Vector3(0.18, -0.06, 0.2), Vector3.ZERO, ally)


## Display-piece idle: a gentle bob; the spectral ally also drifts.
func _idle_sway() -> void:
	var bob := create_tween().set_loops()
	bob.tween_property(visual, "position:y", 0.045, 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(visual, "position:y", 0.0, 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if ally != null:
		var drift := create_tween().set_loops()
		drift.tween_property(ally, "position:y", ally.position.y + 0.14, 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.tween_property(ally, "position:y", ally.position.y, 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- primitive helpers ------------------------------------------------------

func _mesh(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO,
		parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.rotation = rot
	(parent if parent != null else visual).add_child(node)
	return node


func _box(size: Vector3, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO,
		parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(mesh, mat, pos, rot, parent)


func _sphere_mesh(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


func _cylinder(top: float, bottom: float, height: float, mat: Material, pos: Vector3,
		rot: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	return _mesh(mesh, mat, pos, rot, parent)


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return mesh
