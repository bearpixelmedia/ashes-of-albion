extends Node3D
## Champions' Row: the eight-archetype lineup from concept image 2, staged on
## a stone plinth with a sign. The town square instances it on the east side
## of the path; run res://scenes/lineup.tscn on its own for a clean,
## concept-style view (it then adds its own camera, light and floor).

const FIGURE_SCENE := preload("res://scenes/archetype_figure.tscn")
const STONE := preload("res://materials/stone.tres")
const COBBLE := preload("res://materials/cobble.tres")

const PLINTH_HEIGHT := 0.3

@export var spacing := 1.8
@export var show_plinth := true
## True when the scene is run directly (F6) rather than instanced in-world.
@export var standalone_view := false

var figures: Array = []


func _ready() -> void:
	_build_row()
	if standalone_view:
		_build_standalone_view()


func _build_row() -> void:
	var count: int = ClassKit.ARCHETYPES.size()
	var start := -spacing * (count - 1) * 0.5
	for i in count:
		var figure = FIGURE_SCENE.instantiate()  # untyped: the figure owns its members
		figure.archetype_index = i  # set before add_child: the figure builds in _ready
		figure.position = Vector3(start + i * spacing,
			PLINTH_HEIGHT if show_plinth else 0.0, 0.0)
		add_child(figure)
		figures.append(figure)
	if show_plinth:
		_build_plinth(count)
	_build_sign()


func _build_plinth(count: int) -> void:
	var width := spacing * (count - 1) + 2.4
	var body := StaticBody3D.new()
	body.name = "Plinth"
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, PLINTH_HEIGHT, 2.0)
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.shape = shape
	col.position = Vector3(0, PLINTH_HEIGHT * 0.5, 0)
	body.add_child(col)
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	mesh_node.mesh = mesh
	mesh_node.set_surface_override_material(0, STONE)
	body.add_child(mesh_node)
	add_child(body)


func _build_sign() -> void:
	var title := Label3D.new()
	title.name = "SignTitle"
	title.text = "CHAMPIONS' ROW"
	title.font_size = 72
	title.outline_size = 16
	title.modulate = Color(0.95, 0.8, 0.4, 1)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.position = Vector3(0, 3.5, 0)
	add_child(title)
	var subtitle := Label3D.new()
	subtitle.name = "SignSubtitle"
	subtitle.text = "The eight archetypes of Albion"
	subtitle.font_size = 40
	subtitle.outline_size = 10
	subtitle.modulate = Color(0.9, 0.9, 0.85, 0.9)
	subtitle.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	subtitle.position = Vector3(0, 3.0, 0)
	add_child(subtitle)


## Only runs when the lineup scene itself is the running scene.
func _build_standalone_view() -> void:
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(40, 0.4, 30)
	floor_mesh.mesh = floor_box
	floor_mesh.set_surface_override_material(0, COBBLE)
	floor_mesh.position = Vector3(0, -0.2, 0)
	add_child(floor_mesh)

	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.07, 0.08, 0.12)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.4, 0.44, 0.6)
	environment.ambient_light_energy = 0.9
	world_env.environment = environment
	add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.7, 0.5, 0)
	light.light_energy = 1.1
	light.shadow_enabled = true
	add_child(light)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	add_child(camera)
	camera.position = Vector3(0, 2.6, 11.5)
	camera.look_at(Vector3(0, 1.3, 0))
	camera.current = true
