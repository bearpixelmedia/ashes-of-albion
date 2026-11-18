class_name MandateKit
## The mayor's mandate and the world it changes. When the mayoral ballot in the
## Town Hall closes, the winning candidate's role is sealed here; the world reads
## these static modifiers, so a mandate won on the title screen also greets a
## world entered afterwards. Divine mends the player, Economic triples the crowns
## a defeat pays, Military thickens every wave and Scientific shortens cooldowns.

const DETAILS := {
	"Divine": "the faithful are mended (+2 HP/s)",
	"Economic": "each defeat pays triple crowns",
	"Military": "an extra bulwark joins every wave",
	"Scientific": "skill cooldowns fall by 40%",
}

const DIVINE_HEAL := 2.0
const ECONOMIC_CROWN_MULTIPLIER := 3
const MILITARY_EXTRA_FOES := 1
const SCIENTIFIC_COOLDOWN_SCALE := 0.6

static var mayor := ""
static var role := ""
static var detail := ""


## Seal the ballot for one of the Town Hall candidates.
static func apply(candidate: Dictionary) -> void:
	mayor = str(candidate.get("name", ""))
	role = str(candidate.get("role", ""))
	detail = str(DETAILS.get(role, ""))


## No mayor rules Ashford (a ballot sealed without a vote, or a fresh session).
static func clear() -> void:
	mayor = ""
	role = ""
	detail = ""


static func is_active() -> bool:
	return role != ""


static func heal_per_second() -> float:
	return DIVINE_HEAL if role == "Divine" else 0.0


static func crowns_per_kill(base: int) -> int:
	return base * ECONOMIC_CROWN_MULTIPLIER if role == "Economic" else base


static func extra_foes() -> int:
	return MILITARY_EXTRA_FOES if role == "Military" else 0


static func cooldown_scale() -> float:
	return SCIENTIFIC_COOLDOWN_SCALE if role == "Scientific" else 1.0


## The HUD line for the active mandate; empty while the ballot is open.
static func headline() -> String:
	if not is_active():
		return ""
	return "MANDATE · %s  %s — %s" % [mayor.to_upper(), role, detail]
