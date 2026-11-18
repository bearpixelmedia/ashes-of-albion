extends SceneTree
## Audits the loaded main scene and the character-select scene for
## MeshInstance3D nodes with a null mesh (source of headless "Parameter m is
## null" warnings).
## Run: godot --headless --path . --script res://tests/mesh_audit.gd

var frame := 0
var scenes: Array = []


func _initialize() -> void:
	scenes.append(load("res://scenes/main.tscn").instantiate())
	scenes.append(load("res://scenes/character_select.tscn").instantiate())
	for scene in scenes:
		root.add_child(scene)


func _process(_delta: float) -> bool:
	frame += 1
	if frame < 4:
		return false
	var missing := 0
	var total := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is MeshInstance3D:
			total += 1
			if node.mesh == null:
				missing += 1
				print("NULL_MESH: ", node.get_path())
	print("AUDIT total_mesh_instances=", total, " null_meshes=", missing)
	return true
