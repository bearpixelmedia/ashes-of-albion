extends Node3D
## Builds the dusk town square from reusable prop scenes and the compact
## combat arena from primitive pieces. Positions use north = -Z; the path
## runs from the spawn (z > 0) north through the gate into the arena.

const ARENA_Z := -26.0

const STONE := preload("res://materials/stone.tres")
const COBBLE := preload("res://materials/cobble.tres")
const TIMBER := preload("res://materials/timber.tres")
const CLOTH_RED := preload("res://materials/cloth_red.tres")
const CLOTH_GREEN := preload("res://materials/cloth_green.tres")
const CLOTH_BLUE := preload("res://materials/cloth_blue.tres")
const CLOTH_GOLD := preload("res://materials/cloth_gold.tres")

@export var stall_scene: PackedScene
@export var banner_scene: PackedScene
@export var torch_scene: PackedScene
@export var building_scene: PackedScene

# pos, rot_y, awning material index (0 green, 1 red, 2 gold, 3 blue)
const STALLS := [
	[Vector3(-5.5, 0, 9), -PI / 2, 0],
	[Vector3(5.5, 0, 9), PI / 2, 1],
	[Vector3(-5.5, 0, 1), -PI / 2, 2],
	[Vector3(5.5, 0, 1), PI / 2, 3],
]

# pos, rot_y, scale
const BUILDINGS := [
	[Vector3(-13, 0, 6), -PI / 2, Vector3(1.1, 1.0, 1.0)],
	[Vector3(13, 0, 6), PI / 2, Vector3(0.9, 1.15, 1.0)],
	[Vector3(-13, 0, -4), -PI / 2, Vector3(1.0, 0.95, 1.1)],
	[Vector3(13, 0, -4), PI / 2, Vector3(1.15, 1.05, 1.0)],
	[Vector3(-12, 0, 15), -PI / 2, Vector3(1.0, 1.0, 1.0)],
	[Vector3(12, 0, 15), PI / 2, Vector3(1.05, 1.0, 1.0)],
	[Vector3(0, 0, 19), 0.0, Vector3(1.3, 1.1, 1.0)],
]

const BANNER_Z := [12.0, 6.0, 0.0, -6.0, -12.0]
const BANNER_COLORS := [CLOTH_GREEN, CLOTH_RED, CLOTH_BLUE, CLOTH_GOLD]

const PATH_TORCHES := [
	Vector3(-4.6, 0, 12), Vector3(4.6, 0, 12),
	Vector3(-4.6, 0, 6), Vector3(4.6, 0, 6),
	Vector3(-4.6, 0, 0), Vector3(4.6, 0, 0),
	Vector3(-4.6, 0, -6), Vector3(4.6, 0, -6),
	Vector3(-4.6, 0, -12), Vector3(4.6, 0, -12),
	Vector3(-4.4, 0, -16), Vector3(4.4, 0, -16),
	Vector3(-6.5, 0, -21), Vector3(6.5, 0, -21),
	Vector3(-6.5, 0, -31), Vector3(6.5, 0, -31),
]


func _ready() -> void:
	_build_town()
	_build_arena()


func _build_town() -> void:
	for entry in STALLS:
		_spawn(stall_scene, entry[0], entry[1], Vector3.ONE,
			BANNER_COLORS[entry[2]], "Awning")
	for entry in BUILDINGS:
		_spawn(building_scene, entry[0], entry[1], entry[2])

	var banner_index := 0
	for side in [-4.2, 4.2]:
		for z_pos in BANNER_Z:
			var rot_y := -PI / 2 if side < 0 else PI / 2
			_spawn(banner_scene, Vector3(side, 0, z_pos), rot_y, Vector3.ONE,
				BANNER_COLORS[banner_index % BANNER_COLORS.size()], "Cloth")
			banner_index += 1

	for torch_pos in PATH_TORCHES:
		_spawn(torch_scene, torch_pos, 0.0, Vector3.ONE)


func _build_arena() -> void:
	# Floor disc, flush with the square.
	_static_cylinder(Vector3(0, -0.18, ARENA_Z), 9.0, 0.4, COBBLE)

	# Boundary walls with a gate gap on the south (+Z) side.
	_static_box(Vector3(0, 1.5, ARENA_Z - 9.4), Vector3(19, 3, 0.8), STONE)
	_static_box(Vector3(-9.4, 1.5, ARENA_Z), Vector3(0.8, 3, 19), STONE)
	_static_box(Vector3(9.4, 1.5, ARENA_Z), Vector3(0.8, 3, 19), STONE)
	_static_box(Vector3(-6.35, 1.5, ARENA_Z + 9.1), Vector3(6.7, 3, 0.8), STONE)
	_static_box(Vector3(6.35, 1.5, ARENA_Z + 9.1), Vector3(6.7, 3, 0.8), STONE)

	# Gate frame.
	_static_box(Vector3(-3.4, 2.0, ARENA_Z + 9.1), Vector3(0.8, 4, 0.8), STONE)
	_static_box(Vector3(3.4, 2.0, ARENA_Z + 9.1), Vector3(0.8, 4, 0.8), STONE)
	_static_box(Vector3(0, 4.3, ARENA_Z + 9.1), Vector3(7.6, 0.6, 0.9), STONE)

	# Central pillar and low cover.
	_static_cylinder(Vector3(0, 1.75, ARENA_Z), 0.9, 3.5, STONE)
	_static_box(Vector3(-5, 0.6, ARENA_Z + 5), Vector3(2.4, 1.2, 1.2), STONE, 0.3)
	_static_box(Vector3(5, 0.6, ARENA_Z + 5), Vector3(2.4, 1.2, 1.2), STONE, -0.3)
	_static_box(Vector3(-5, 0.6, ARENA_Z - 5), Vector3(2.4, 1.2, 1.2), STONE, -0.2)
	_static_box(Vector3(5, 0.6, ARENA_Z - 5), Vector3(2.4, 1.2, 1.2), STONE, 0.2)

	# Two raised platforms (jumpable).
	_static_box(Vector3(-5.5, 0.225, ARENA_Z), Vector3(3.5, 0.45, 3.5), STONE)
	_static_box(Vector3(5.5, 0.225, ARENA_Z), Vector3(3.5, 0.45, 3.5), STONE)


func _spawn(scene: PackedScene, pos: Vector3, rot_y: float, spawn_scale: Vector3,
		color_mat: Material = null, color_node_path: String = "") -> void:
	if scene == null:
		push_warning("town_layout: missing scene at %s" % pos)
		return
	var node := scene.instantiate() as Node3D
	node.position = pos
	node.rotation.y = rot_y
	node.scale = spawn_scale
	if color_mat != null and color_node_path != "":
		var color_node := node.get_node_or_null(color_node_path)
		if color_node is MeshInstance3D:
			color_node.set_surface_override_material(0, color_mat)
	add_child(node)


func _static_box(pos: Vector3, size: Vector3, mat: Material, rot_y: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rot_y
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.set_surface_override_material(0, mat)
	body.add_child(mesh_node)
	add_child(body)
	return body


func _static_cylinder(pos: Vector3, radius: float, height: float, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	body.add_child(col)
	var mesh_node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh_node.mesh = mesh
	mesh_node.set_surface_override_material(0, mat)
	body.add_child(mesh_node)
	add_child(body)
	return body
