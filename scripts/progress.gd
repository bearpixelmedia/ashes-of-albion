class_name Progress
## The player's persistent record, kept in a small ConfigFile save under
## user:// so it survives quitting the game: renown earned across runs, the
## personal best arena run, and the third hotbar slot each class earns by
## clearing the arena.
##
## Nothing here touches the scene tree; main.gd feeds it kills/waves/clears and
## the HUD and character card read it back.

const SAVE_PATH := "user://progress.cfg"
const SECTION := "progress"

const RENOWN_PER_KILL := 5
const RENOWN_PER_WAVE := 15
const RENOWN_ARENA_CLEAR := 40

## Overridable so the headless suite can keep its own save file.
static var save_path := SAVE_PATH

static var renown := 0
static var best_waves := 0
static var best_kills := 0
static var best_time := 0.0
## The champion Enter World last committed; the next launch boots it.
static var last_class := ""

static var _unlocked: Array[String] = []
static var _loaded := false


## Load the save once; every caller (world boot, select screen) can ask.
static func ensure_loaded() -> void:
	if not _loaded:
		load_save()


## Read the save file back, replacing whatever is in memory. A missing or
## unreadable file simply leaves the defaults (a first run).
static func load_save() -> void:
	_clear()
	_loaded = true
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return
	renown = maxi(int(file.get_value(SECTION, "renown", 0)), 0)
	best_waves = maxi(int(file.get_value(SECTION, "best_waves", 0)), 0)
	best_kills = maxi(int(file.get_value(SECTION, "best_kills", 0)), 0)
	best_time = maxf(float(file.get_value(SECTION, "best_time", 0.0)), 0.0)
	last_class = str(file.get_value(SECTION, "class", ""))
	if not last_class.is_empty() and ClassKit.is_playable(last_class):
		ClassKit.selected = last_class  # the world and the picker resume on it
	for id in file.get_value(SECTION, "unlocked", PackedStringArray()):
		var class_id := str(id)
		if class_id != "" and not _unlocked.has(class_id):
			_unlocked.append(class_id)


## Drop the in-memory copy and read the file again, exactly as a fresh launch
## would. (Not named reload(): GDScript resolves that to the native
## GDScript.reload(), which would reset every static here.)
static func relaunch() -> void:
	_clear()
	_loaded = false
	ensure_loaded()


## Wipe the record and delete its save file.
static func forget() -> void:
	_clear()
	_loaded = true
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


static func save_now() -> void:
	var file := ConfigFile.new()
	file.set_value(SECTION, "renown", renown)
	file.set_value(SECTION, "best_waves", best_waves)
	file.set_value(SECTION, "best_kills", best_kills)
	file.set_value(SECTION, "best_time", best_time)
	file.set_value(SECTION, "class", last_class)
	file.set_value(SECTION, "unlocked", PackedStringArray(_unlocked))
	file.save(save_path)


# --- renown ----------------------------------------------------------------

## Renown earned by a kill, a cleared wave or a whole cleared arena.
static func add_renown(amount: int) -> void:
	ensure_loaded()
	if amount <= 0:
		return
	renown += amount
	save_now()


static func renown_for_kill() -> void:
	add_renown(RENOWN_PER_KILL)


static func renown_for_wave() -> void:
	add_renown(RENOWN_PER_WAVE)


static func renown_for_arena() -> void:
	add_renown(RENOWN_ARENA_CLEAR)


# --- personal best run -----------------------------------------------------

## Record a finished arena run. The best is the furthest run (waves cleared),
## with kills and then the faster clock breaking ties. Returns true when the
## run became the new best.
static func record_run(waves: int, kills: int, seconds: float) -> bool:
	ensure_loaded()
	if waves <= 0:
		return false
	if not _beats_best(waves, kills, seconds):
		return false
	best_waves = waves
	best_kills = kills
	best_time = maxf(seconds, 0.0)
	save_now()
	return true


static func _beats_best(waves: int, kills: int, seconds: float) -> bool:
	if waves != best_waves:
		return waves > best_waves
	if kills != best_kills:
		return kills > best_kills
	return best_time <= 0.0 or seconds < best_time


## e.g. "Wave 3 · 01:12", or "—" before the first run.
static func best_text() -> String:
	if best_waves <= 0:
		return "—"
	var minutes := int(best_time) / 60
	var seconds := int(best_time) % 60
	return "Wave %d · %02d:%02d" % [best_waves, minutes, seconds]


# --- last committed class --------------------------------------------------

## Remember the champion the select screen just committed: the next launch
## reopens the picker on it and the world boots it instead of the fighter.
static func remember_class(class_id: String) -> void:
	ensure_loaded()
	if class_id.is_empty() or not ClassKit.is_playable(class_id):
		return
	last_class = class_id
	ClassKit.selected = class_id
	save_now()


# --- earned third slot -----------------------------------------------------

## Unlock a class's third skill slot; returns true when it was newly earned.
static func unlock_slot(class_id: String) -> bool:
	ensure_loaded()
	if class_id == "" or _unlocked.has(class_id):
		return false
	_unlocked.append(class_id)
	save_now()
	return true


static func is_slot_unlocked(class_id: String) -> bool:
	ensure_loaded()
	return _unlocked.has(class_id)


static func unlocked_classes() -> Array:
	ensure_loaded()
	return _unlocked.duplicate()


## "Third slot earned: Fighter · Ranger", or the instruction when none is.
static func unlock_summary() -> String:
	ensure_loaded()
	if _unlocked.is_empty():
		return "Third slot locked — clear the arena"
	var names: Array[String] = []
	for id in _unlocked:
		names.append(str(ClassKit.by_id(id).get("name", id)))
	return "Third slot earned: " + " · ".join(names)


static func _clear() -> void:
	renown = 0
	last_class = ""
	best_waves = 0
	best_kills = 0
	best_time = 0.0
	_unlocked = []
