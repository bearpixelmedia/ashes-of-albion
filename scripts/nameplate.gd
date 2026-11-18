extends Label3D
## Faction nameplate over a combatant's head (concept image 6): the entity's
## name with a colour-coded tag — ALLY (green), COMBATANT (gold) or CORRUPTED
## (red). Attach to a Label3D and pick the faction; the scene's own text is
## kept as the name unless `title_text` overrides it.

@export var faction := "combatant"
@export var title_text := ""

const TAGS := {
	"ally": "ALLY",
	"combatant": "COMBATANT",
	"corrupted": "CORRUPTED",
}
const COLORS := {
	"ally": Color(0.55, 0.9, 0.55),
	"combatant": Color(0.95, 0.82, 0.45),
	"corrupted": Color(0.92, 0.38, 0.34),
}


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	if title_text == "":
		title_text = text
	refresh()


func refresh() -> void:
	modulate = COLORS.get(faction, Color.WHITE)
	text = "%s\n%s" % [title_text, TAGS.get(faction, "COMBATANT")]


func set_title(value: String) -> void:
	title_text = value
	refresh()
