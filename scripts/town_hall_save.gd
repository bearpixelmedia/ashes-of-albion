class_name TownHallSave
## The Town Hall's saved citizen sheet, written to user://town_hall.json:
## citizenship, the ZOI house registered with it and the renounce cooldown.
## Claiming Ashford makes the player a citizen (and registers their ZOI house);
## renouncing drops both and starts a 14-day cooldown before Ashford can be
## claimed again. The cooldown is a Unix stamp, so it keeps running while the
## game is closed and resumes at the right second on the next launch. The
## election itself (ballot, tallies, incumbent, cycle) is saved by ElectionKit.

const PATH := "user://town_hall.json"
const RENOUNCE_SECONDS := 1209600.0

## Overridable so the headless suite never touches the player's real save.
static var path := PATH

static var loaded := false
static var citizen := false
static var housing := false  # ZOI house registered; only citizens may hold one
static var renounce_end := 0.0  # Unix stamp; 0 = no cooldown running


static func now() -> float:
	return Time.get_unix_time_from_system()


## Read the save once per session (idempotent).
static func ensure_loaded() -> void:
	if loaded:
		return
	loaded = true
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return
	citizen = bool(data.get("citizen", false))
	housing = bool(data.get("housing", false)) and citizen
	renounce_end = float(data.get("renounce_end", 0.0))


## Drop the in-memory copy and read the file again — what a relaunch does.
static func reload_from_disk() -> void:
	loaded = false
	citizen = false
	housing = false
	renounce_end = 0.0
	ensure_loaded()


static func save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"citizen": citizen,
		"housing": housing,
		"renounce_end": renounce_end,
	}, "\t") + "\n")


## Wipe the save: a brand-new session (and the headless suite's isolation).
static func reset() -> void:
	loaded = true
	citizen = false
	housing = false
	renounce_end = 0.0
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Claim Ashford: citizenship plus the ZOI house. Refused while a renounce
## cooldown runs (or when already a citizen).
static func claim() -> bool:
	if citizen or cooldown_left() > 0.0:
		return false
	citizen = true
	housing = true
	renounce_end = 0.0
	save()
	return true


## Renounce Ashford: both perks go and the 14-day cooldown starts.
static func renounce() -> bool:
	if not citizen:
		return false
	citizen = false
	housing = false
	renounce_end = now() + RENOUNCE_SECONDS
	save()
	return true


## Seconds left on the renounce cooldown (0 when none is running).
static func cooldown_left() -> float:
	if citizen or renounce_end <= 0.0:
		return 0.0
	return maxf(0.0, renounce_end - now())


## Register or unregister the ZOI house (citizens only).
static func set_housing(registered: bool) -> void:
	if not citizen:
		return
	housing = registered
	save()
