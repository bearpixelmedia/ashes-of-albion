class_name Progression
## The run's progression spine: kills award experience, every level grants one
## skill point, and level 25 opens the Fighter tree's Secondary Archetype rail.
##
## The champion starts at level 12 — the state the concept art shows — which
## owns the tree's eight-point pool. Levels above 12 add one point each, so a
## level-25 champion holds 21 points: exactly the tree's unlocked capacity.
## The XP curve is flat (100 per level) to keep the prototype readable.

const START_LEVEL := 12
const XP_PER_LEVEL := 100
const XP_PER_KILL := 50
const BASE_POINTS := 8
const POINTS_PER_LEVEL := 1
const SECONDARY_LEVEL := 25

static var level := START_LEVEL
static var xp := 0
static var secondary := ""


static func reset() -> void:
	level = START_LEVEL
	xp = 0
	secondary = ""


## Bank experience and roll any levels it completes. Returns levels gained.
static func add_xp(amount: int) -> int:
	var gained := 0
	xp += maxi(amount, 0)
	while xp >= XP_PER_LEVEL:
		xp -= XP_PER_LEVEL
		level += 1
		gained += 1
	return gained


static func award_kill() -> int:
	return add_xp(XP_PER_KILL)


static func points_total() -> int:
	return BASE_POINTS + maxi(level - START_LEVEL, 0) * POINTS_PER_LEVEL


static func secondary_unlocked() -> bool:
	return level >= SECONDARY_LEVEL
