class_name UiStyle
extends RefCounted
## The gold/dark button boxes shared by the title screen, character select, the
## Town Hall and the pause menu. Construction and palette live here; each screen
## only picks its silhouette — the front end uses radius 8, the in-game panels 7,
## and the dark border is the muted gold in the hall but the accent gold in the
## pause menu. Those differences are arguments, not copies.

const ACCENT := Color(1.0, 0.82, 0.35)
const ACCENT_BRIGHT := Color(1.0, 0.85, 0.45)
const ACCENT_MUTED := Color(0.85, 0.66, 0.2)
const ACCENT_HOVER := Color(1.0, 0.9, 0.55)


## Filled gold primary button (same palette in all four screens).
static func gold(radius := 8) -> StyleBoxFlat:
	return box(Color(0.82, 0.6, 0.16, 1.0), ACCENT_BRIGHT, 2, radius)


## Brighter gold for hover/focus on the in-game panels.
static func gold_hover(radius := 7) -> StyleBoxFlat:
	return box(Color(0.92, 0.7, 0.22, 1.0), ACCENT_HOVER, 2, radius)


## Dark secondary button.
static func dark(radius := 8, bg_alpha := 0.95,
		border := ACCENT_MUTED, border_alpha := 0.45) -> StyleBoxFlat:
	return box(Color(0.08, 0.085, 0.12, bg_alpha), with_alpha(border, border_alpha), 1, radius)


## Dark secondary button, hovered or focused.
static func dark_hover(radius := 8, border := ACCENT, border_alpha := 0.8) -> StyleBoxFlat:
	return box(Color(0.12, 0.12, 0.17, 0.98), with_alpha(border, border_alpha), 1, radius)


static func box(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


static func with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


## Paint a button's states in one call; a null state is left as the theme set it.
static func paint(button: Button, normal: StyleBox, hover: StyleBox = null,
		pressed: StyleBox = null, focus: StyleBox = null) -> void:
	button.add_theme_stylebox_override("normal", normal)
	if hover != null:
		button.add_theme_stylebox_override("hover", hover)
	if pressed != null:
		button.add_theme_stylebox_override("pressed", pressed)
	if focus != null:
		button.add_theme_stylebox_override("focus", focus)
