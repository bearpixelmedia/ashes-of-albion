class_name UiGlyph
extends Control
## Procedural glyphs for the Town Hall panel: hourglass, sun, coins, crossed
## swords, flask, scroll, hammer, house and check mark. Everything is drawn
## from primitives, so the screen needs no icon textures and stays crisp at
## any size.

enum Kind { HOURGLASS, SUN, COINS, SWORDS, FLASK, SCROLL, HAMMER, HOUSE, CHECK }

@export var kind: Kind = Kind.SUN:
	set(value):
		kind = value
		queue_redraw()

@export var color: Color = Color(1.0, 0.82, 0.35):
	set(value):
		color = value
		queue_redraw()

@export var accent: Color = Color(0.07, 0.06, 0.05, 1.0):
	set(value):
		accent = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var side := minf(size.x, size.y)
	if side <= 0.0:
		return
	var center := size * 0.5
	match kind:
		Kind.HOURGLASS:
			_draw_hourglass(center, side)
		Kind.SUN:
			_draw_sun(center, side)
		Kind.COINS:
			_draw_coins(center, side)
		Kind.SWORDS:
			_draw_swords(center, side)
		Kind.FLASK:
			_draw_flask(center, side)
		Kind.SCROLL:
			_draw_scroll(center, side)
		Kind.HAMMER:
			_draw_hammer(center, side)
		Kind.HOUSE:
			_draw_house(center, side)
		Kind.CHECK:
			_draw_check(center, side)


func _stroke(side: float) -> float:
	return maxf(1.5, side * 0.055)


func _draw_hourglass(c: Vector2, s: float) -> void:
	var half_w := s * 0.2
	var top := c.y - s * 0.31
	var bottom := c.y + s * 0.31
	var stroke := _stroke(s)
	draw_line(Vector2(c.x - half_w * 1.35, top), Vector2(c.x + half_w * 1.35, top), color, stroke)
	draw_line(Vector2(c.x - half_w * 1.35, bottom), Vector2(c.x + half_w * 1.35, bottom), color, stroke)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - half_w, top + s * 0.04),
		Vector2(c.x + half_w, top + s * 0.04),
		Vector2(c.x, c.y - s * 0.02),
	]), color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - half_w, bottom - s * 0.04),
		Vector2(c.x + half_w, bottom - s * 0.04),
		Vector2(c.x, c.y + s * 0.02),
	]), color)


func _draw_sun(c: Vector2, s: float) -> void:
	draw_circle(c, s * 0.2, color)
	for i in 8:
		var dir := Vector2.from_angle(TAU * float(i) / 8.0)
		draw_line(c + dir * s * 0.31, c + dir * s * 0.45, color, maxf(1.5, s * 0.055))


func _draw_coins(c: Vector2, s: float) -> void:
	var rx := s * 0.3
	var ry := s * 0.12
	for i in 3:
		var cy := c.y + s * 0.2 - float(i) * s * 0.16
		var tint := color.darkened(0.22 * float(2 - i))
		draw_colored_polygon(_ellipse(Vector2(c.x, cy + s * 0.045), rx, ry, 26), tint)
		draw_colored_polygon(_ellipse(Vector2(c.x, cy), rx, ry, 26), color)
	draw_line(Vector2(c.x - s * 0.04, c.y - s * 0.17), Vector2(c.x + s * 0.04, c.y - s * 0.17),
			accent, maxf(1.0, s * 0.04))


func _draw_swords(c: Vector2, s: float) -> void:
	var stroke := maxf(2.0, s * 0.085)
	for direction: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
		var dir: Vector2 = direction.normalized()
		var tip: Vector2 = c + dir * s * 0.36
		var pommel: Vector2 = c - dir * s * 0.32
		draw_line(pommel, tip, color, stroke)
		var guard: Vector2 = tip - dir * s * 0.14
		var across: Vector2 = Vector2(-dir.y, dir.x) * s * 0.14
		draw_line(guard - across, guard + across, color.darkened(0.3), stroke * 0.8)
		draw_circle(pommel, s * 0.045, color.darkened(0.3))


func _draw_flask(c: Vector2, s: float) -> void:
	var neck := s * 0.15
	draw_rect(Rect2(c.x - neck * 0.5, c.y - s * 0.36, neck, s * 0.22), color)
	draw_line(Vector2(c.x - neck, c.y - s * 0.36), Vector2(c.x + neck, c.y - s * 0.36),
			color, maxf(1.5, s * 0.05))
	var body := PackedVector2Array([
		Vector2(c.x - s * 0.1, c.y - s * 0.15),
		Vector2(c.x + s * 0.1, c.y - s * 0.15),
		Vector2(c.x + s * 0.3, c.y + s * 0.3),
		Vector2(c.x - s * 0.3, c.y + s * 0.3),
	])
	draw_colored_polygon(body, color)
	var liquid := PackedVector2Array([
		Vector2(c.x - s * 0.21, c.y + s * 0.1),
		Vector2(c.x + s * 0.21, c.y + s * 0.1),
		Vector2(c.x + s * 0.3, c.y + s * 0.3),
		Vector2(c.x - s * 0.3, c.y + s * 0.3),
	])
	draw_colored_polygon(liquid, color.lightened(0.3))


func _draw_scroll(c: Vector2, s: float) -> void:
	var w := s * 0.54
	var h := s * 0.6
	var origin := Vector2(c.x - w * 0.5, c.y - h * 0.5)
	draw_rect(Rect2(origin, Vector2(w, h)), color)
	var curl := w * 0.16
	draw_circle(Vector2(origin.x + curl, origin.y), curl, color.darkened(0.15))
	draw_circle(Vector2(origin.x + curl, origin.y + h), curl, color.darkened(0.25))
	for i in 3:
		var y := origin.y + h * (0.3 + float(i) * 0.2)
		draw_line(Vector2(origin.x + w * 0.32, y), Vector2(origin.x + w * 0.86, y),
				accent, maxf(1.0, s * 0.03))


func _draw_hammer(c: Vector2, s: float) -> void:
	var handle := Vector2(s * 0.28, s * 0.28)
	draw_line(c - handle, c + handle, color.darkened(0.2), maxf(2.0, s * 0.1))
	var head_center := c - handle
	draw_colored_polygon(_rotated_rect(head_center, Vector2(s * 0.26, s * 0.11), -PI * 0.25), color)
	draw_colored_polygon(_rotated_rect(head_center + Vector2(-s * 0.12, s * 0.12),
			Vector2(s * 0.1, s * 0.12), -PI * 0.25), color.darkened(0.12))


func _draw_house(c: Vector2, s: float) -> void:
	var w := s * 0.6
	var h := s * 0.42
	var base_y := c.y + s * 0.3
	draw_rect(Rect2(c.x - w * 0.5, base_y - h, w, h), color.darkened(0.08))
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - w * 0.64, base_y - h),
		Vector2(c.x + w * 0.64, base_y - h),
		Vector2(c.x, base_y - h - s * 0.32),
	]), color)
	draw_rect(Rect2(c.x - w * 0.09, base_y - h * 0.52, w * 0.18, h * 0.52), accent)
	draw_rect(Rect2(c.x - w * 0.38, base_y - h * 0.8, w * 0.15, h * 0.22), color.lightened(0.55))
	draw_rect(Rect2(c.x + w * 0.23, base_y - h * 0.8, w * 0.15, h * 0.22), color.lightened(0.55))


func _draw_check(c: Vector2, s: float) -> void:
	var points := PackedVector2Array([
		Vector2(c.x - s * 0.26, c.y + s * 0.02),
		Vector2(c.x - s * 0.06, c.y + s * 0.22),
		Vector2(c.x + s * 0.28, c.y - s * 0.22),
	])
	draw_polyline(points, color, maxf(2.0, s * 0.15), true)


func _ellipse(center: Vector2, rx: float, ry: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps:
		var angle := TAU * float(i) / float(steps)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points


func _rotated_rect(center: Vector2, extents: Vector2, angle: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		points.append(center + (corner * extents).rotated(angle))
	return points
