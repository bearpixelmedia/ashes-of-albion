class_name SaveGame
extends RefCounted
## The run's persistent profile in `user://save.cfg`: the committed champion,
## its level, the fighter skill tree's ranks, and the audio/display settings.
##
## Boot screens call restore() once; the picker, the skill tree and the
## settings panel save on change. `path` and `auto` exist as a test seam so the
## headless suite can point at a scratch file and keep a developer's own save
## out of the run.

const DEFAULT_PATH := "user://save.cfg"

static var path := DEFAULT_PATH
static var auto := true


## Boot-time entry point: load the last run unless the suite disabled it.
static func restore() -> bool:
	if not auto:
		return false
	return restore_from(path)


## Read a save file into the live statics (class, level, tree, settings).
static func restore_from(source: String) -> bool:
	if not FileAccess.file_exists(source):
		return false
	var config := ConfigFile.new()
	if config.load(source) != OK:
		return false
	apply({
		"class": config.get_value("champion", "class", ClassKit.selected),
		"level": config.get_value("champion", "level", Progression.START_LEVEL),
		"xp": config.get_value("champion", "xp", 0),
		"secondary": config.get_value("champion", "secondary", ""),
		"tree": config.get_value("champion", "tree", {}),
		"volume": config.get_value("audio", "volume", 0.8),
		"muted": config.get_value("audio", "muted", false),
		"fullscreen": config.get_value("display", "fullscreen", false),
	})
	return true


static func apply(data: Dictionary) -> void:
	var champion := str(data.get("class", ClassKit.selected))
	if not ClassKit.by_id(champion).is_empty():
		ClassKit.selected = champion
	Progression.level = maxi(int(data.get("level", Progression.START_LEVEL)), 1)
	Progression.xp = maxi(int(data.get("xp", 0)), 0)
	var secondary := str(data.get("secondary", ""))
	Progression.secondary = secondary if not ClassKit.by_id(secondary).is_empty() else ""
	var tree: Dictionary = data.get("tree", {})
	SkillTreeData.load_ranks(tree)
	var volume := clampf(float(data.get("volume", 0.8)), 0.0, 1.0)
	AudioServer.set_bus_mute(0, bool(data.get("muted", false)))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN if bool(data.get("fullscreen", false))
				else DisplayServer.WINDOW_MODE_WINDOWED)


## Write the current class, level, tree and settings to `path`.
static func save() -> void:
	var config := ConfigFile.new()
	config.set_value("champion", "class", ClassKit.selected)
	config.set_value("champion", "level", Progression.level)
	config.set_value("champion", "xp", Progression.xp)
	config.set_value("champion", "secondary", Progression.secondary)
	SkillTreeData.ensure()
	config.set_value("champion", "tree", SkillTreeData.ranks.duplicate())
	config.set_value("audio", "volume", db_to_linear(AudioServer.get_bus_volume_db(0)))
	config.set_value("audio", "muted", AudioServer.is_bus_mute(0))
	config.set_value("display", "fullscreen",
			DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	config.save(path)


## Remove a save file (the suite's scratch file, or a deliberate reset).
static func erase(target := "") -> void:
	var file := target if target != "" else path
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
