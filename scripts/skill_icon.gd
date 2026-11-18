extends Control
## Tiny line-drawn icons for the skill tree (crossed swords, arcs, shields,
## fist, whirlwind, tower…). Kept as geometry so the screen needs no textures
## and every icon stays crisp at node size and in the secondary-type rail.

@export var kind := "swords"
@export var tint := Color(0.97, 0.87, 0.6)


func set_kind(value: String) -> void:
	kind = value
	queue_redraw()


func set_tint(value: Color) -> void:
	tint = value
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var side := minf(size.x, size.y)
	if side <= 2.0:
		return
	var c := size * 0.5
	var w := maxf(1.5, side * 0.075)
	match kind:
		"arc", "cleave":
			_arc(c, side, w, 0.34 if kind == "cleave" else 0.3)
		"shield":
			_shield(c, side, w)
		"guard":
			_shield(c, side, w)
			draw_line(c + Vector2(0, -side * 0.22), c + Vector2(0, side * 0.24),
					tint, w, true)
		"sunder":
			_shield(c, side, w)
			draw_line(c + Vector2(-side * 0.16, -side * 0.3),
					c + Vector2(side * 0.16, side * 0.32), tint, w * 1.3, true)
		"whirl":
			for i in 3:
				draw_arc(c, side * (0.11 + 0.08 * i), deg_to_rad(-30.0 + i * 120.0),
						deg_to_rad(190.0 + i * 120.0), 20, tint, w, true)
		"fist":
			var body := Rect2(c - Vector2(side * 0.2, side * 0.1),
					Vector2(side * 0.4, side * 0.3))
			draw_rect(body, tint, false, w)
			for i in 3:
				var x := c.x - side * 0.12 + i * side * 0.12
				draw_line(Vector2(x, c.y - side * 0.1),
						Vector2(x, c.y + side * 0.2), tint, w * 0.8, true)
			draw_line(c + Vector2(-side * 0.1, side * 0.26),
					c + Vector2(side * 0.1, side * 0.26), tint, w, true)
		"wind":
			for i in 3:
				var y := c.y - side * 0.16 + i * side * 0.16
				var line := PackedVector2Array([
					Vector2(c.x - side * 0.3, y),
					Vector2(c.x - side * 0.08, y - side * 0.06),
					Vector2(c.x + side * 0.14, y + side * 0.06),
					Vector2(c.x + side * 0.3, y),
				])
				draw_polyline(line, tint, w * 0.9, true)
		"tower":
			var body := Rect2(c + Vector2(-side * 0.2, -side * 0.2),
					Vector2(side * 0.4, side * 0.5))
			draw_rect(body, tint, false, w)
			for i in 3:
				var x := body.position.x + side * 0.03 + i * side * 0.12
				draw_rect(Rect2(Vector2(x, body.position.y - side * 0.1),
						Vector2(side * 0.07, side * 0.11)), tint, true)
			draw_rect(Rect2(c + Vector2(-side * 0.06, side * 0.12),
					Vector2(side * 0.12, side * 0.18)), tint, true)
		"bow":
			draw_arc(c + Vector2(-side * 0.14, 0), side * 0.34, -PI * 0.5, PI * 0.5, 20,
					tint, w, true)
			draw_line(c + Vector2(-side * 0.14, -side * 0.34),
					c + Vector2(-side * 0.14, side * 0.34), tint, w * 0.6, true)
			draw_line(c + Vector2(-side * 0.2, 0), c + Vector2(side * 0.28, 0),
					tint, w * 0.8, true)
			draw_line(c + Vector2(side * 0.28, 0), c + Vector2(side * 0.14, -side * 0.12),
					tint, w * 0.7, true)
			draw_line(c + Vector2(side * 0.28, 0), c + Vector2(side * 0.14, side * 0.12),
					tint, w * 0.7, true)
		"dash":
			for i in 2:
				var x := c.x - side * 0.16 + i * side * 0.22
				var chevron := PackedVector2Array([
					Vector2(x - side * 0.1, c.y - side * 0.2),
					Vector2(x + side * 0.1, c.y),
					Vector2(x - side * 0.1, c.y + side * 0.2),
				])
				draw_polyline(chevron, tint, w, true)
		"lock":
			draw_arc(c + Vector2(0, -side * 0.1), side * 0.2, PI, TAU, 20, tint, w, true)
			draw_rect(Rect2(c + Vector2(-side * 0.26, -side * 0.1),
					Vector2(side * 0.52, side * 0.36)), tint, true)
		_:
			_swords(c, side, w)


func _swords(c: Vector2, side: float, w: float) -> void:
	var d := Vector2(side * 0.3, side * 0.3)
	draw_line(c - d, c + d, tint, w, true)
	draw_line(c + Vector2(d.x, -d.y), c + Vector2(-d.x, d.y), tint, w, true)
	# Hilts sit at the lower end of each blade.
	draw_line(c + Vector2(-d.x, d.y * 0.2), c + Vector2(-d.x * 0.2, d.y),
			tint, w * 0.8, true)
	draw_line(c + Vector2(d.x, d.y * 0.2), c + Vector2(d.x * 0.2, d.y),
			tint, w * 0.8, true)


func _arc(c: Vector2, side: float, w: float, radius: float) -> void:
	draw_arc(c, side * radius, deg_to_rad(35.0), deg_to_rad(315.0), 28, tint, w, true)
	draw_arc(c, side * radius * 0.58, deg_to_rad(50.0), deg_to_rad(300.0), 24,
			tint, w * 0.7, true)


func _shield(c: Vector2, side: float, w: float) -> void:
	var outline := PackedVector2Array([
		c + Vector2(-side * 0.26, -side * 0.3),
		c + Vector2(side * 0.26, -side * 0.3),
		c + Vector2(side * 0.26, side * 0.02),
		c + Vector2(0, side * 0.34),
		c + Vector2(-side * 0.26, side * 0.02),
		c + Vector2(-side * 0.26, -side * 0.3),
	])
	draw_polyline(outline, tint, w, true)
