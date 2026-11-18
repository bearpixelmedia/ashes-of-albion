extends Control
## Elbow connectors between skill-tree nodes, drawn from the shared layout in
## SkillTreeData so the lines always meet the nodes they belong to.

const GOLD := Color(0.85, 0.68, 0.28, 0.85)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	SkillTreeData.ensure()
	resized.connect(queue_redraw)


func _draw() -> void:
	for definition in SkillTreeData.NODES:
		var parent_id := str(definition["parent"])
		if parent_id == "":
			continue
		var parent := SkillTreeData.node_by_id(parent_id)
		if parent.is_empty():
			continue
		var parent_size: Vector2 = parent["size"]
		var size: Vector2 = definition["size"]
		var from: Vector2 = parent["pos"] + Vector2(parent_size.x * 0.5, parent_size.y)
		var to: Vector2 = definition["pos"] + Vector2(size.x * 0.5, 0)
		var mid_y := (from.y + to.y) * 0.5
		var elbow := PackedVector2Array([
			from, Vector2(from.x, mid_y), Vector2(to.x, mid_y), to,
		])
		draw_polyline(elbow, GOLD, 2.0, true)
		draw_circle(to, 2.5, GOLD)
