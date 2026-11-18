extends Control
## Gold tree-of-life crest drawn from lines: the emblem that recurs across the
## concept art (character-select panel, house banners, Town Hall sign). Used at
## small sizes, so it stays a simple trunk/branch/root glyph in a ring.

@export var line_color := Color(0.9, 0.72, 0.28)
@export var ring := true
@export var line_width := 2.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var side := minf(size.x, size.y)
	if side <= 2.0:
		return
	var center := size * 0.5
	var width := maxf(1.2, side * 0.05)
	if ring:
		draw_arc(center, side * 0.5 - line_width, 0.0, TAU, 48, line_color,
				line_width, true)
	# Branches fan up from a short trunk, roots splay at the base.
	var trunk_base := center + Vector2(0, side * 0.30)
	var trunk_top := center + Vector2(0, side * 0.02)
	draw_line(trunk_base, trunk_top, line_color, width, true)
	for limb in [
			[Vector2(0, 0.02), Vector2(-0.24, -0.20)],
			[Vector2(0, 0.02), Vector2(0.24, -0.20)],
			[Vector2(0, 0.12), Vector2(-0.26, -0.02)],
			[Vector2(0, 0.12), Vector2(0.26, -0.02)],
			[Vector2(0, 0.30), Vector2(-0.20, 0.42)],
			[Vector2(0, 0.30), Vector2(0.20, 0.42)],
	]:
		draw_line(center + limb[0] * side, center + limb[1] * side,
				line_color, width * 0.8, true)
	# Leaf clusters at the branch tips: what turns the glyph into a tree at
	# small sizes instead of a trident.
	for tip in [Vector2(-0.24, -0.20), Vector2(0.24, -0.20),
			Vector2(-0.26, -0.02), Vector2(0.26, -0.02), Vector2(0, -0.16)]:
		draw_circle(center + tip * side, side * 0.045, line_color)
