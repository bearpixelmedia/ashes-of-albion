extends Node3D
## Cathedral backdrop for the character-select dais (concept image 3): a stone
## hall with a moonlit window, hanging house banners, torch sconces, a red
## carpet, three ghostly champions on plinths and a gold knot on the floor.
## Built from engine primitives, like the rest of the prototype's art.

const STONE := preload("res://materials/stone.tres")
const COBBLE := preload("res://materials/cobble.tres")
const CLOTH_GOLD := preload("res://materials/cloth_gold.tres")
const TIMBER := preload("res://materials/timber.tres")

var _dark: StandardMaterial3D
var _crimson: StandardMaterial3D
var _banner_red: StandardMaterial3D
var _banner_green: StandardMaterial3D
var _moon: StandardMaterial3D
var _gold: StandardMaterial3D
var _ghost: StandardMaterial3D
var _flame: StandardMaterial3D


func _ready() -> void:
	_dark = _flat(Color(0.035, 0.045, 0.08))
	_crimson = _flat(Color(0.3, 0.05, 0.08))
	_banner_red = _flat(Color(0.34, 0.06, 0.09))
	_banner_green = _flat(Color(0.08, 0.2, 0.11))
	_moon = _glow(Color(0.62, 0.74, 1.0), 0.9)
	_gold = _gold_metal()
	_ghost = _spectral()
	_flame = _glow(Color(1.0, 0.66, 0.28), 2.2)
	_build_walls()
	_build_arches()
	_build_banners()
	_build_torches()
	_build_carpet()
	_build_ghosts()
	_build_knot()


# --- the hall ----------------------------------------------------------------

func _build_walls() -> void:
	_box(Vector3(17, 0.3, 14), Vector3(0, -0.3, -1.0), COBBLE)
	_box(Vector3(17, 10, 0.4), Vector3(0, 4.8, -7.4), STONE)
	_box(Vector3(0.4, 10, 14), Vector3(-8.3, 4.8, -1.0), STONE)
	_box(Vector3(0.4, 10, 14), Vector3(8.3, 4.8, -1.0), STONE)
	_box(Vector3(17, 0.4, 14), Vector3(0, 9.7, -1.0), STONE)
	# Moonlit window, high behind the dais, framed in gold.
	_cylinder(0.85, 0.08, Vector3(0, 4.6, -7.0), _moon, Vector3(90, 0, 0))
	_torus(0.87, 0.99, Vector3(0, 4.6, -6.96), CLOTH_GOLD, Vector3(90, 0, 0))


func _build_arches() -> void:
	for x in [-3.9, 0.0, 3.9]:
		# Recessed gothic opening with a pointed, gold-trimmed head.
		_box(Vector3(2.4, 4.6, 0.12), Vector3(x, 3.0, -7.16), _dark)
		_box(Vector3(1.55, 0.2, 0.16), Vector3(x - 0.42, 5.5, -7.1),
				CLOTH_GOLD, Vector3(0, 0, 30))
		_box(Vector3(1.55, 0.2, 0.16), Vector3(x + 0.42, 5.5, -7.1),
				CLOTH_GOLD, Vector3(0, 0, -30))
		_box(Vector3(0.14, 5.0, 0.16), Vector3(x, 3.0, -7.1), STONE)
	for x in [-5.9, -1.9, 1.9, 5.9]:
		_cylinder(0.3, 7.0, Vector3(x, 3.2, -7.05), STONE)
		_box(Vector3(0.8, 0.16, 0.5), Vector3(x, 6.7, -7.05), CLOTH_GOLD)


func _build_banners() -> void:
	for entry in [
			[-5.6, _banner_red], [-2.6, _banner_green],
			[2.6, _banner_green], [5.6, _banner_red]]:
		var x: float = entry[0]
		_quad(Vector2(0.95, 2.4), Vector3(x, 4.4, -7.05), entry[1])
		_box(Vector3(1.12, 0.1, 0.14), Vector3(x, 5.62, -7.02), CLOTH_GOLD)
		_box(Vector3(1.02, 0.14, 0.1), Vector3(x, 3.18, -7.02), CLOTH_GOLD)


func _build_torches() -> void:
	for x in [-5.6, 5.6]:
		_box(Vector3(0.16, 0.16, 0.5), Vector3(x, 3.1, -6.9), TIMBER)
		_cylinder(0.16, 0.22, Vector3(x, 3.2, -6.6), STONE)
		_sphere(0.16, Vector3(x, 3.42, -6.6), _flame)
		var light := OmniLight3D.new()
		light.position = Vector3(x, 3.5, -6.1)
		light.light_color = Color(1.0, 0.72, 0.4)
		light.light_energy = 2.6
		light.omni_range = 7.5
		add_child(light)
	# Warm key on the champion plus a soft fill, so the dais reads like the
	# torchlit hall of the concept.
	var key := OmniLight3D.new()
	key.position = Vector3(0, 2.4, 3.2)
	key.light_color = Color(1.0, 0.88, 0.7)
	key.light_energy = 2.0
	key.omni_range = 7.0
	add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 4.2, 3.4)
	fill.light_color = Color(1.0, 0.78, 0.5)
	fill.light_energy = 0.9
	fill.omni_range = 12.0
	add_child(fill)


func _build_carpet() -> void:
	_box(Vector3(2.5, 0.05, 9.0), Vector3(0, 0.02, 0.6), _crimson)
	for x in [-1.25, 1.25]:
		_box(Vector3(0.08, 0.07, 9.0), Vector3(x, 0.03, 0.6), CLOTH_GOLD)


func _build_ghosts() -> void:
	for x in [-1.9, 0.0, 1.9]:
		_cylinder(0.42, 0.5, Vector3(x, 0.25, -2.9), STONE)
		var body := CapsuleMesh.new()
		body.radius = 0.26
		body.height = 1.15
		_instance(body, Vector3(x, 1.08, -2.9), _ghost, Vector3.ZERO)
		var head := SphereMesh.new()
		head.radius = 0.17
		head.height = 0.34
		_instance(head, Vector3(x, 1.8, -2.9), _ghost, Vector3.ZERO)


## Gold triquetra laid flat on the floor in front of the dais.
func _build_knot() -> void:
	for i in 3:
		var angle := deg_to_rad(90.0 + i * 120.0)
		var offset := Vector3(cos(angle) * 0.17, 0.07, 1.95 + sin(angle) * 0.17)
		_torus(0.19, 0.26, offset, _gold)


# --- primitive helpers --------------------------------------------------------

func _box(size: Vector3, pos: Vector3, material: Material,
		rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _instance(mesh, pos, material, rot_deg)


func _cylinder(radius: float, height: float, pos: Vector3, material: Material,
		rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	return _instance(mesh, pos, material, rot_deg)


func _sphere(radius: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _instance(mesh, pos, material, Vector3.ZERO)


func _torus(inner: float, outer: float, pos: Vector3, material: Material,
		rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	return _instance(mesh, pos, material, rot_deg)


func _quad(size: Vector2, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	return _instance(mesh, pos, material, Vector3.ZERO)


func _instance(mesh: Mesh, pos: Vector3, material: Material,
		rot_deg: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.rotation_degrees = rot_deg
	node.set_surface_override_material(0, material)
	add_child(node)
	return node


# --- materials ----------------------------------------------------------------

func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _gold_metal() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.72, 0.24)
	material.metallic = 0.85
	material.roughness = 0.32
	material.emission_enabled = true
	material.emission = Color(0.6, 0.42, 0.1)
	material.emission_energy_multiplier = 0.35
	return material


func _spectral() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.4, 0.62, 1.0, 0.34)
	material.emission_enabled = true
	material.emission = Color(0.35, 0.55, 1.0)
	material.emission_energy_multiplier = 1.2
	return material
