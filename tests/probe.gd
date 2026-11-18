extends SceneTree
## One-shot probe: where does SpringArm3D put the camera, and does it look
## back at the player? Run: godot --headless --path . --script res://tests/probe.gd

var frame := 0
var player: Node3D


func _initialize() -> void:
	player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)


func _process(_delta: float) -> bool:
	frame += 1
	if frame < 6:
		return false
	var cam: Camera3D = player.get_node("SpringArm3D/Camera3D")
	var local: Vector3 = player.to_local(cam.global_position)
	var to_player: Vector3 = (player.global_position + Vector3(0, 1.4, 0) - cam.global_position)
	var look: Vector3 = -cam.global_transform.basis.z
	print("PROBE camera_local=", local, " look_dot=", look.dot(to_player.normalized()),
			" arm_rot=", player.get_node("SpringArm3D").rotation)
	return true
