extends Node
## Diagnostic: does the harrier actually fire, and where does the bolt go?
## Run: godot --headless --path . res://tests/probe_harrier.tscn

var main


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 6:
		await get_tree().physics_frame

	var player = main.player
	# isolate the ranged duel: take the placed opponents out of play first
	main.dummy.take_damage(99999.0)
	main.warden.take_damage(99999.0)
	var harrier = load("res://scenes/harrier.tscn").instantiate()
	harrier.position = Vector3(-8.0, 0.9, -33.5)
	main.get_node("ArenaFoes").add_child(harrier)
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(-8.0, 0.85, -24.0)
	player.rotation.y = 0.0

	print("PROBE kind=", harrier.kind, " projectile_scene=", harrier.projectile_scene,
			" aggro=", harrier.aggro_range, " shoot=", harrier.shoot_range,
			" pref_min=", harrier.preferred_min, " cd0=", harrier._attack_cd)

	for i in 600:
		await get_tree().physics_frame
		if i % 60 == 0 or i == 599:
			var bolts := 0
			bolts = _count_bolts(main, bolts)
			print("  t=", i, " state=", harrier.state, " cd=", snappedf(harrier._attack_cd, 0.01),
					" hpos=", harrier.global_position,
					" dist=", snappedf(harrier.global_position.distance_to(player.global_position), 0.1),
					" bolts=", bolts, " php=", player.hp, " ppos=", player.global_position)
	print("PROBE_DONE php=", player.hp, " final_state=", harrier.state)
	get_tree().quit(0)


func _count_bolts(node: Node, count: int) -> int:
	var n := count
	for child in node.get_children():
		if String(child.name).begins_with("Projectile"):
			n += 1
		n = _count_bolts(child, n)
	return n
