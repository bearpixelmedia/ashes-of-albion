class_name PauseMenu
extends OverlayPanel
## In-world Esc menu, opened by main as an overlay. Like the Town Hall it hands
## control back with `closed`: main owns the freeze and the resume, so this screen
## only knows about Resume, the Settings stub and Return to Title.

signal title_requested

@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var return_button: Button = %ReturnToTitle
@onready var status_label: Label = %PauseStatus


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_style_buttons()
	resume_button.grab_focus()
	# Each entry is its signal: no in-between handlers to keep in sync.
	resume_button.pressed.connect(closed.emit)
	settings_button.pressed.connect(show_settings)
	return_button.pressed.connect(title_requested.emit)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()  # the world must not reopen the menu
		closed.emit()


## The title screen's Settings button is a Phase 6 stub; the pause menu reuses it.
func show_settings() -> void:
	status_label.text = "Settings — audio, keybindings and camera options arrive in Phase 6."


# --- styling ----------------------------------------------------------------

## The gold/dark boxes come from the shared UiStyle helper.
func _style_buttons() -> void:
	var gold := UiStyle.gold(7)
	var gold_hover := UiStyle.gold_hover()
	var dark := UiStyle.dark(7, 0.96, UiStyle.ACCENT, 0.45)
	var dark_hover := UiStyle.dark_hover(7, UiStyle.ACCENT, 1.0)
	UiStyle.paint(resume_button, gold, gold_hover, gold_hover, gold_hover)
	resume_button.add_theme_color_override("font_color", Color(0.12, 0.08, 0.03))
	resume_button.add_theme_color_override("font_hover_color", Color(0.12, 0.08, 0.03))
	resume_button.add_theme_color_override("font_pressed_color", Color(0.12, 0.08, 0.03))
	UiStyle.paint(settings_button, dark, dark_hover, dark_hover, dark_hover)
	UiStyle.paint(return_button, dark, dark_hover, dark_hover, dark_hover)
