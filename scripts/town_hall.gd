class_name TownHallPanel
extends OverlayPanel
## Town Hall (concept image 5): the Citizenship & Election panel. The left half
## shows the settlement of Ashford, housing in the ZOI, the one-per-server
## citizenship claim and the 14-day renounce cooldown. The right half runs the
## mayoral election (ElectionKit): Aveline (Divine), Merrin (Economic), Garrick
## (Military) and Ilyra (Scientific) on a live 24 h clock. A citizen casts one
## ballot, the ballot locks, the clock's expiry counts the tally and the results
## name the winner and the incumbent before the next cycle opens. The winner's
## mandate is sealed into MandateKit and the world changes to match; a tie seals
## nothing. Both halves stay on screen as in the concept; the tabs raise one
## panel's border and focus its primary control. Citizenship and the renounce
## cooldown are saved to user:// (TownHallSave); the election saves itself.

signal ballot_sealed(candidate: Dictionary)
signal citizenship_changed(citizen: bool)

const GLYPH := preload("res://scripts/ui_glyph.gd")
const TORCH_SCENE := preload("res://scenes/props/torch.tscn")
const COBBLE := preload("res://materials/cobble.tres")

const GOLD := Color(0.85, 0.66, 0.2)
const GOLD_BRIGHT := Color(1.0, 0.82, 0.35)
const CREAM := Color(0.94, 0.91, 0.83)
const PANEL_BG := Color(0.055, 0.06, 0.09, 0.97)
const CARD_BG := Color(0.08, 0.08, 0.11, 0.95)
const ELECTION_RED := Color(0.34, 0.09, 0.06, 1.0)

## "kind" is a UiGlyph.Kind: HOURGLASS 0, SUN 1, COINS 2, SWORDS 3, FLASK 4,
## SCROLL 5, HAMMER 6, HOUSE 7, CHECK 8. Names, roles and tallies live in
## ElectionKit; this table only carries each candidate's panel styling.
const CANDIDATE_STYLES: Array[Dictionary] = [
	{"kind": 1, "color": Color(0.98, 0.82, 0.32), "avatar": Color(0.34, 0.26, 0.1)},
	{"kind": 2, "color": Color(0.42, 0.85, 0.38), "avatar": Color(0.12, 0.28, 0.14)},
	{"kind": 3, "color": Color(0.9, 0.36, 0.3), "avatar": Color(0.3, 0.12, 0.12)},
	{"kind": 4, "color": Color(0.38, 0.72, 0.96), "avatar": Color(0.12, 0.2, 0.32)},
]
const MANDATES: Array[Dictionary] = [
	{"label": "Propose policy", "kind": 5, "color": GOLD_BRIGHT},
	{"label": "Adjust taxes", "kind": 2, "color": Color(0.95, 0.78, 0.3)},
	{"label": "Issue commissions", "kind": 6, "color": Color(0.9, 0.72, 0.42)},
]

var rows: Array = []
var mandate_buttons: Array = []
var selected_candidate := -1
var is_citizen := false
var embedded := false  # opened over the world: Back closes instead of loading the title
var active_tab := 1
var results_panel: Panel = null
var results_title: Label = null
var results_footer: Label = null
var tally_list: VBoxContainer = null
var next_button: Button = null

var _clock := 0.0
var _row_parts: Array = []
var _torch_lights: Array[OmniLight3D] = []

var _panel_idle: StyleBoxFlat
var _panel_focus: StyleBoxFlat
var _tab_idle: StyleBoxFlat
var _tab_active: StyleBoxFlat
var _row_idle: StyleBoxFlat
var _row_hover: StyleBoxFlat
var _row_selected: StyleBoxFlat
var _btn_gold: StyleBoxFlat
var _btn_gold_hover: StyleBoxFlat
var _btn_dark: StyleBoxFlat
var _btn_dark_hover: StyleBoxFlat

@onready var sign_panel: Panel = %SignPanel
@onready var left_panel: Panel = %LeftPanel
@onready var right_panel: Panel = %RightPanel
@onready var citizenship_tab: Button = %CitizenshipTab
@onready var election_tab: Button = %ElectionTab
@onready var ballot_list: VBoxContainer = %BallotList
@onready var timer_label: Label = %TimerLabel
@onready var incumbent_label: Label = %IncumbentLabel
@onready var cast_button: Button = %CastButton
@onready var claim_button: Button = %ClaimButton
@onready var renounce_button: Button = %RenounceButton
@onready var housing_check: Button = %HousingCheck
@onready var housing_mark_box: Panel = %HousingMarkBox
@onready var housing_mark: Control = %HousingMark
@onready var cooldown_value: Label = %CooldownValue
@onready var left_status: Label = %LeftStatus
@onready var right_status: Label = %RightStatus
@onready var mandate_row: HBoxContainer = %MandateRow
@onready var back_button: Button = %BackButton
@onready var camera: Camera3D = %Camera3D
@onready var diorama: Node3D = %Diorama


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	TownHallSave.ensure_loaded()
	ElectionKit.ensure_loaded()
	is_citizen = TownHallSave.citizen
	_build_styles()
	_build_ballot()
	_build_mandates()
	_build_results()
	_build_diorama()
	housing_check.toggled.connect(_on_housing_toggled)
	_refresh_citizenship()
	ElectionKit.maybe_resolve()  # the clock may have run out while the game was closed
	_refresh_election()
	focus_panel(1)


func _process(delta: float) -> void:
	_clock += delta
	if ElectionKit.maybe_resolve():
		_on_ballot_resolved()
	timer_label.text = format_clock(ElectionKit.remaining())
	_update_cooldown()
	for i in _torch_lights.size():
		_torch_lights[i].light_energy = 2.1 + sin(_clock * 6.3 + float(i) * 1.9) * 0.4


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()  # one Esc must not also open the pause menu
		go_title()


# --- panel behaviour ---------------------------------------------------------

## Pick a candidate (or clear the pick with a negative index). The pick only
## becomes a ballot when cast_ballot() runs, and a cast ballot locks the rows.
func select_candidate(index: int) -> void:
	if ElectionKit.phase != ElectionKit.OPEN:
		right_status.text = "The ballot is closed — the count is in."
		return
	if ElectionKit.vote >= 0:
		right_status.text = "One vote per election — your ballot is already cast for %s." \
				% _candidate_name(ElectionKit.vote)
		return
	if index < 0 or index >= ElectionKit.CANDIDATES.size():
		selected_candidate = -1
		_apply_row_styles()
		cast_button.disabled = true
		right_status.text = "Choose a candidate, then cast your ballot."
		return
	selected_candidate = index
	var candidate: Dictionary = ElectionKit.CANDIDATES[index]
	_apply_row_styles()
	cast_button.disabled = not is_citizen
	if not is_citizen:
		right_status.text = "Claim citizenship on the left to vote for %s." % candidate["name"]
		return
	right_status.text = "%s — %s mandate. Cast your ballot before the clock runs out (%s)." % [
		candidate["name"], str(candidate["role"]), format_clock(ElectionKit.remaining())]


## Raise one half of the hall (0 = Citizenship, 1 = Election) and focus it.
func focus_panel(index: int) -> void:
	active_tab = clampi(index, 0, 1)
	_apply_tab_styles()
	if active_tab == 0:
		if not claim_button.disabled:
			claim_button.grab_focus()
	elif not rows.is_empty():
		var target := selected_candidate if selected_candidate >= 0 else 0
		rows[target].grab_focus()


## Claim citizenship of Ashford — one claim per server. The claim registers the
## ZOI house, makes Ashford home/respawn and unlocks the mayoral ballot.
func claim_citizenship() -> bool:
	if is_citizen:
		return false
	var cooling := TownHallSave.cooldown_left()
	if cooling > 0.0:
		left_status.text = "Ashford cannot be claimed again for %s — the renounce cooldown is still running." \
				% format_cooldown(cooling)
		return false
	if not TownHallSave.claim():
		return false
	_refresh_citizenship()
	left_status.text = "You are a citizen of Ashford — home and respawn set to the hall, the ZOI house registered and your ballot unlocked."
	citizenship_changed.emit(true)
	return true


## Renounce Ashford: the ZOI house, home and respawn go with the citizenship and
## the 14-day cooldown starts before the settlement can be claimed again.
func renounce_citizenship() -> bool:
	if not is_citizen:
		return false
	TownHallSave.renounce()
	_refresh_citizenship()
	left_status.text = "You renounced Ashford — home, respawn and the ZOI house are gone. The 14-day cooldown has begun."
	citizenship_changed.emit(false)
	return true


## The left half drives the right: citizenship unlocks the ballot, the ZOI house
## and the Ashford respawn. Buttons and texts follow the saved citizen sheet.
func _refresh_citizenship() -> void:
	is_citizen = TownHallSave.citizen
	var cooling := TownHallSave.cooldown_left()
	claim_button.disabled = is_citizen or cooling > 0.0
	if is_citizen:
		claim_button.text = "Citizen of Ashford"
	elif cooling > 0.0:
		claim_button.text = "Claim in %s" % format_cooldown(cooling)
	else:
		claim_button.text = "Claim citizenship"
	renounce_button.disabled = not is_citizen
	housing_check.disabled = not is_citizen
	housing_check.set_pressed_no_signal(is_citizen and TownHallSave.housing)
	housing_mark.visible = housing_check.button_pressed
	_apply_housing_style()
	_update_cooldown()


func _update_cooldown() -> void:
	var left := TownHallSave.cooldown_left()
	cooldown_value.text = format_cooldown(left if left > 0.0 else TownHallSave.RENOUNCE_SECONDS)
	if is_citizen or not claim_button.disabled:
		return
	if left > 0.0:
		claim_button.text = "Claim in %s" % format_cooldown(left)
	else:
		_refresh_citizenship()  # the 14-day cooldown has run out: claim again


## Cast the picked candidate: one ballot per election. The lockout lives in
## ElectionKit, so it survives closing the hall and a relaunch.
func cast_ballot() -> bool:
	if ElectionKit.phase != ElectionKit.OPEN:
		right_status.text = "The ballot is closed — the count is in."
		return false
	if not is_citizen:
		right_status.text = "Only a citizen of Ashford may vote — claim citizenship on the left."
		return false
	if ElectionKit.vote >= 0:
		right_status.text = "One vote per election — already cast for %s." \
				% _candidate_name(ElectionKit.vote)
		return false
	if selected_candidate < 0:
		right_status.text = "Choose a candidate before casting your ballot."
		return false
	if not ElectionKit.cast_vote(selected_candidate):
		return false
	_lock_ballot("Ballot cast")
	right_status.text = "You cast your ballot for %s — one vote per election. The count opens at 00:00:00." \
			% _candidate_name(selected_candidate)
	return true


## Count the ballot now (the 24 h clock does this on its own at expiry).
func close_ballot() -> void:
	if ElectionKit.phase != ElectionKit.OPEN:
		return
	ElectionKit.resolve()
	_on_ballot_resolved()


## Open the next election: fresh clock, unlocked ballot, the incumbent one vote
## ahead in the opening tallies.
func start_next_cycle() -> void:
	ElectionKit.begin_cycle()
	results_panel.visible = false
	selected_candidate = -1
	_apply_row_styles()
	_unlock_ballot()
	_refresh_incumbent()
	timer_label.text = format_clock(ElectionKit.remaining())
	right_status.text = "Election %d is open — cast your ballot for the next mayor of Ashford." \
			% ElectionKit.cycle
	focus_panel(1)


## The count is in: show the results, lock the ballot and seal the winner's
## mandate into the world (a tie seals nothing and keeps the sitting mayor).
func _on_ballot_resolved() -> void:
	var counted: Dictionary = ElectionKit.result
	_show_results(counted)
	_lock_ballot("Ballot closed")
	_refresh_incumbent()
	var winner_index := int(counted.get("winner", -1))
	var top := int(counted.get("top", 0))
	if winner_index >= 0:
		var winner: Dictionary = ElectionKit.CANDIDATES[winner_index]
		right_status.text = "%s wins the mayoralty with %d votes — the %s mandate is sealed." % [
			winner["name"], top, str(winner["role"])]
		ballot_sealed.emit(winner)
		return
	var mayor := ElectionKit.incumbent_candidate()
	if mayor.is_empty():
		right_status.text = "The ballot is tied at %d votes — no mayor takes office." % top
	else:
		right_status.text = "The ballot is tied at %d votes — %s keeps the mayor's mandate." % [
			top, mayor["name"]]


## Bring the whole panel in line with the saved election state.
func _refresh_election() -> void:
	timer_label.text = format_clock(ElectionKit.remaining())
	_refresh_incumbent()
	if ElectionKit.vote >= 0:
		selected_candidate = ElectionKit.vote
		_apply_row_styles()
		_lock_ballot("Ballot cast")
		right_status.text = "You cast your ballot for %s — one vote per election." \
				% _candidate_name(ElectionKit.vote)
	elif ElectionKit.phase == ElectionKit.RESULTS:
		_apply_row_styles()
		_lock_ballot("Ballot closed")
		right_status.text = "The ballot is closed — the count is in."
	else:
		selected_candidate = -1
		_apply_row_styles()
		_unlock_ballot()
		right_status.text = "Choose a candidate, then cast your ballot." if is_citizen \
				else "Claim citizenship on the left to vote in Ashford's mayoral election."
	if ElectionKit.phase == ElectionKit.RESULTS:
		_show_results(ElectionKit.result)


func _refresh_incumbent() -> void:
	var mayor := ElectionKit.incumbent_candidate()
	if mayor.is_empty():
		incumbent_label.text = "No incumbent — Ashford's first election"
	else:
		incumbent_label.text = "Incumbent: %s · %s" % [mayor["name"], str(mayor["role"])]


## One vote per election: the rows and the cast button lock until the next cycle.
func _lock_ballot(label: String) -> void:
	for row in rows:
		row.disabled = true
	cast_button.text = label
	cast_button.disabled = true


func _unlock_ballot() -> void:
	for row in rows:
		row.disabled = false
	cast_button.text = "Cast ballot"
	cast_button.disabled = selected_candidate < 0 or not is_citizen


func _candidate_name(index: int) -> String:
	if index < 0 or index >= ElectionKit.CANDIDATES.size():
		return "nobody"
	return str(ElectionKit.CANDIDATES[index]["name"])


## Back/Esc: hand the overlay back to the world, or leave for the title when the
## hall was opened on its own. The world guards its own close, so this is stateless.
func go_title() -> void:
	if embedded:
		closed.emit()
	else:
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


func format_clock(seconds: float) -> String:
	var total := int(maxf(0.0, ceil(seconds)))
	return "%02d:%02d:%02d" % [total / 3600, (total % 3600) / 60, total % 60]


func format_cooldown(seconds: float) -> String:
	var total := int(maxf(0.0, ceil(seconds)))
	return "%dd %02dh" % [total / 86400, (total % 86400) / 3600]


func _on_mandate(index: int) -> void:
	if not is_citizen:
		right_status.text = "Only a citizen of Ashford can carry the mayor's mandate."
		return
	if index < 0 or index >= MANDATES.size():
		return
	right_status.text = "%s — the mandate unlocks for the winner when the ballot closes." \
			% MANDATES[index]["label"]


func _on_housing_toggled(pressed: bool) -> void:
	if not is_citizen:
		housing_check.set_pressed_no_signal(false)
		housing_mark.visible = false
		_apply_housing_style()
		left_status.text = "Only a citizen of Ashford can register a house in the ZOI."
		return
	TownHallSave.set_housing(pressed)
	housing_mark.visible = pressed
	_apply_housing_style()
	if pressed:
		left_status.text = "Housing in the ZOI registered — your home counts toward Ashford's population."
	else:
		left_status.text = "Housing in the ZOI unregistered."


func _on_citizenship_tab() -> void:
	focus_panel(0)


func _on_election_tab() -> void:
	focus_panel(1)


# --- construction: ballot + mandate -----------------------------------------

func _build_ballot() -> void:
	for i in ElectionKit.CANDIDATES.size():
		var candidate: Dictionary = ElectionKit.CANDIDATES[i]
		var style: Dictionary = CANDIDATE_STYLES[i]
		var row := Button.new()
		row.name = "Candidate%d" % i
		row.custom_minimum_size = Vector2(700, 78)
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.pressed.connect(select_candidate.bind(i))

		var radio := Panel.new()
		radio.name = "CandidateRadio"
		radio.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_add_at(row, radio, Rect2(16, 25, 28, 28))

		var avatar := Panel.new()
		avatar.name = "CandidateAvatar"
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar.add_theme_stylebox_override("panel", UiStyle.box(style["avatar"],
				UiStyle.with_alpha(style["color"], 0.7), 1, 28))
		_add_at(row, avatar, Rect2(56, 11, 56, 56))

		var initial := _label(str(candidate["name"]).left(1), 26, CREAM,
				HORIZONTAL_ALIGNMENT_CENTER)
		initial.name = "Initial"
		avatar.add_child(initial)
		initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		var name_label := _label(str(candidate["name"]), 26, CREAM)
		name_label.name = "CandidateName"
		_add_at(row, name_label, Rect2(124, 14, 218, 50))

		var divider := ColorRect.new()
		divider.name = "RowDivider"
		divider.color = UiStyle.with_alpha(GOLD, 0.35)
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_add_at(row, divider, Rect2(354, 13, 1, 52))

		var glyph = GLYPH.new()
		glyph.name = "CandidateGlyph"
		glyph.kind = int(style["kind"])
		glyph.color = style["color"]
		_add_at(row, glyph, Rect2(370, 25, 28, 28))

		var chip := Panel.new()
		chip.name = "RoleChip"
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_add_at(row, chip, Rect2(410, 23, 266, 32))

		var role_label := _label(str(candidate["role"]).to_upper(), 15,
				style["color"], HORIZONTAL_ALIGNMENT_CENTER)
		role_label.name = "RoleLabel"
		chip.add_child(role_label)
		role_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		ballot_list.add_child(row)
		rows.append(row)
		_row_parts.append({"radio": radio, "chip": chip})
	_apply_row_styles()


func _build_mandates() -> void:
	for i in MANDATES.size():
		var mandate: Dictionary = MANDATES[i]
		var button := Button.new()
		button.name = "Mandate%d" % i
		button.custom_minimum_size = Vector2(220, 56)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_mandate.bind(i))
		_style_dark_button(button, true)

		var glyph = GLYPH.new()
		glyph.kind = int(mandate["kind"])
		glyph.color = mandate["color"]
		_add_at(button, glyph, Rect2(14, 13, 30, 30))

		var label := _label(str(mandate["label"]), 15, CREAM)
		_add_at(button, label, Rect2(52, 0, 158, 56))

		mandate_row.add_child(button)
		mandate_buttons.append(button)


## The results overlay: it covers the open ballot once the count is in.
func _build_results() -> void:
	results_panel = Panel.new()
	results_panel.name = "ResultsPanel"
	results_panel.visible = false
	_add_at(right_panel, results_panel, Rect2(20, 74, 700, 382))
	results_panel.add_theme_stylebox_override("panel", UiStyle.box(PANEL_BG, GOLD_BRIGHT, 2, 8))

	results_title = _label("", 26, GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	results_title.name = "ResultsTitle"
	_add_at(results_panel, results_title, Rect2(16, 14, 668, 40))

	tally_list = VBoxContainer.new()
	tally_list.name = "TallyList"
	tally_list.add_theme_constant_override("separation", 6)
	_add_at(results_panel, tally_list, Rect2(24, 62, 652, 160))

	results_footer = _label("", 14, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	results_footer.name = "ResultsFooter"
	results_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_at(results_panel, results_footer, Rect2(16, 232, 668, 58))

	next_button = Button.new()
	next_button.name = "NextElection"
	next_button.text = "Open the next election"
	next_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	next_button.pressed.connect(start_next_cycle)
	_add_at(results_panel, next_button, Rect2(190, 304, 320, 44))
	_style_dark_button(next_button, true)


## Fill the results overlay with the count, the winner and the incumbent.
func _show_results(counted: Dictionary) -> void:
	if results_panel == null:
		return
	var winner_index := int(counted.get("winner", -1))
	var tied := bool(counted.get("tied", false))
	if tied:
		results_title.text = "The ballot is tied"
	elif winner_index >= 0:
		results_title.text = "%s wins the mayoralty" % _candidate_name(winner_index)
	else:
		results_title.text = "No mayor elected"
	_fill_tallies(counted)
	var mayor := ElectionKit.incumbent_candidate()
	var seat := "the seat stays vacant" if mayor.is_empty() \
			else "%s keeps the mayor's mandate" % mayor["name"]
	if tied:
		results_footer.text = "Election %d closed level at %d votes — %s." % [
			int(counted.get("cycle", ElectionKit.cycle)), int(counted.get("top", 0)), seat]
	elif winner_index >= 0:
		results_footer.text = "Election %d: %s takes office with the %s mandate — %s." % [
			int(counted.get("cycle", ElectionKit.cycle)), _candidate_name(winner_index),
			str(ElectionKit.CANDIDATES[winner_index]["role"]), MandateKit.detail]
	else:
		results_footer.text = "Election %d produced no mayor." \
				% int(counted.get("cycle", ElectionKit.cycle))
	results_panel.visible = true


## One tally row per candidate: name, role, votes and who took (or tied) the seat.
func _fill_tallies(counted: Dictionary) -> void:
	for child in tally_list.get_children():
		tally_list.remove_child(child)
		child.queue_free()
	var counted_votes: Array = counted.get("votes", [])
	var leaders: Array = counted.get("leaders", [])
	var winner := int(counted.get("winner", -1))
	for i in ElectionKit.CANDIDATES.size():
		var candidate: Dictionary = ElectionKit.CANDIDATES[i]
		var row := HBoxContainer.new()
		row.name = "Tally%d" % i
		row.add_theme_constant_override("separation", 8)
		var name_label := _label(str(candidate["name"]), 16, CREAM)
		name_label.custom_minimum_size = Vector2(200, 32)
		row.add_child(name_label)
		var role_label := _label(str(candidate["role"]).to_upper(), 13,
				CANDIDATE_STYLES[i]["color"])
		role_label.custom_minimum_size = Vector2(150, 32)
		row.add_child(role_label)
		var votes: int = int(counted_votes[i]) if i < counted_votes.size() else 0
		var count_label := _label("%d votes" % votes, 15, GOLD_BRIGHT,
				HORIZONTAL_ALIGNMENT_RIGHT)
		count_label.custom_minimum_size = Vector2(120, 32)
		row.add_child(count_label)
		var mark_text := ""
		if i == winner:
			mark_text = "◆ elected"
		elif leaders.has(i):
			mark_text = "◆ tied"
		var mark := _label(mark_text, 13, CREAM)
		mark.custom_minimum_size = Vector2(140, 32)
		row.add_child(mark)
		tally_list.add_child(row)


func _apply_row_styles() -> void:
	for i in rows.size():
		var selected := i == selected_candidate
		rows[i].add_theme_stylebox_override("normal",
				_row_selected if selected else _row_idle)
		rows[i].add_theme_stylebox_override("hover",
				_row_selected if selected else _row_hover)
		rows[i].add_theme_stylebox_override("pressed", _row_selected)
		rows[i].add_theme_stylebox_override("focus",
				_row_selected if selected else _row_hover)
		var radio: Panel = _row_parts[i]["radio"]
		radio.add_theme_stylebox_override("panel", UiStyle.box(
				GOLD_BRIGHT if selected else Color(0, 0, 0, 0),
				GOLD_BRIGHT if selected else UiStyle.with_alpha(GOLD, 0.55), 2, 14))
		var chip: Panel = _row_parts[i]["chip"]
		chip.add_theme_stylebox_override("panel", UiStyle.box(CARD_BG,
				UiStyle.with_alpha(CANDIDATE_STYLES[i]["color"], 0.55), 1, 6))


func _apply_housing_style() -> void:
	housing_mark_box.add_theme_stylebox_override("panel", UiStyle.box(
			Color(0.05, 0.05, 0.07, 0.9),
			GOLD_BRIGHT if housing_check.button_pressed else UiStyle.with_alpha(GOLD, 0.5),
			2, 6))


# --- construction: styles ----------------------------------------------------

func _build_styles() -> void:
	_panel_idle = UiStyle.box(PANEL_BG, UiStyle.with_alpha(GOLD, 0.5), 1, 10)
	_panel_focus = UiStyle.box(PANEL_BG, GOLD_BRIGHT, 2, 10)
	_tab_idle = UiStyle.box(Color(0.07, 0.075, 0.105, 0.97), UiStyle.with_alpha(GOLD, 0.45), 1, 5)
	_tab_active = UiStyle.box(ELECTION_RED, GOLD_BRIGHT, 2, 5)
	_row_idle = UiStyle.box(Color(0.06, 0.06, 0.09, 0.92), UiStyle.with_alpha(GOLD, 0.32), 1, 6)
	_row_hover = UiStyle.box(Color(0.1, 0.095, 0.13, 0.96), GOLD, 1, 6)
	_row_selected = UiStyle.box(Color(0.17, 0.11, 0.06, 0.98), GOLD_BRIGHT, 2, 6)
	_btn_gold = UiStyle.gold(7)
	_btn_gold_hover = UiStyle.gold_hover()
	_btn_dark = UiStyle.dark(7, 0.96)
	_btn_dark_hover = UiStyle.dark_hover(7, UiStyle.ACCENT_MUTED, 1.0)

	sign_panel.add_theme_stylebox_override("panel", _panel_focus)
	UiStyle.paint(claim_button, _btn_gold, _btn_gold_hover, _btn_gold, _btn_gold_hover)
	claim_button.add_theme_stylebox_override("disabled", _btn_dark)
	claim_button.add_theme_color_override("font_color", Color(0.12, 0.08, 0.03))
	claim_button.add_theme_color_override("font_hover_color", Color(0.12, 0.08, 0.03))
	claim_button.add_theme_color_override("font_pressed_color", Color(0.12, 0.08, 0.03))
	claim_button.add_theme_color_override("font_disabled_color", GOLD)

	UiStyle.paint(cast_button, _btn_gold, _btn_gold_hover, _btn_gold, _btn_gold_hover)
	cast_button.add_theme_stylebox_override("disabled", _btn_dark)
	cast_button.add_theme_color_override("font_color", Color(0.12, 0.08, 0.03))
	cast_button.add_theme_color_override("font_hover_color", Color(0.12, 0.08, 0.03))
	cast_button.add_theme_color_override("font_pressed_color", Color(0.12, 0.08, 0.03))
	cast_button.add_theme_color_override("font_disabled_color", GOLD)
	_style_dark_button(renounce_button)

	_style_dark_button(housing_check)
	_style_dark_button(back_button)
	_apply_tab_styles()


func _style_dark_button(button: Button, bright_press := false) -> void:
	UiStyle.paint(button, _btn_dark, _btn_dark_hover,
			_btn_dark_hover if bright_press else _btn_dark, _btn_dark_hover)


func _apply_tab_styles() -> void:
	var tabs: Array[Button] = [citizenship_tab, election_tab]
	var panels: Array[Panel] = [left_panel, right_panel]
	for i in tabs.size():
		var active := active_tab == i
		tabs[i].add_theme_stylebox_override("normal",
				_tab_active if active else _tab_idle)
		tabs[i].add_theme_stylebox_override("hover", _tab_active)
		tabs[i].add_theme_stylebox_override("pressed", _tab_active)
		tabs[i].add_theme_stylebox_override("focus",
				_tab_active if active else _tab_idle)
		tabs[i].add_theme_color_override("font_color", GOLD_BRIGHT if active else CREAM)
		panels[i].add_theme_stylebox_override("panel",
				_panel_focus if active else _panel_idle)


func _label(text: String, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _add_at(parent: Control, child: Control, rect: Rect2) -> Control:
	parent.add_child(child)
	child.position = rect.position
	child.size = rect.size
	return child


# --- construction: night town-hall diorama -----------------------------------

func _build_diorama() -> void:
	_add_floor()
	_add_facade()
	var banners := [
		[-4.4, Color(0.8, 0.62, 0.18)],
		[-3.3, Color(0.16, 0.32, 0.66)],
		[3.3, Color(0.18, 0.45, 0.24)],
		[4.4, Color(0.42, 0.18, 0.55)],
	]
	for banner in banners:
		_add_banner(banner[0], banner[1])
	for x in [-6.1, 6.1]:
		_add_torch(x, -4.55)
	_add_sphere(Vector3(-11.5, 13.5, -26), 2.3, Color(0.78, 0.84, 0.98),
			Color(0.72, 0.8, 1.0))
	for point in [Vector3(-15, 12, -26), Vector3(-12, 15, -27), Vector3(-8, 11, -28),
			Vector3(4, 14, -28), Vector3(9, 12, -27), Vector3(14, 15, -26),
			Vector3(2, 10, -29), Vector3(-4, 16, -26)]:
		_add_sphere(point, 0.11, Color(0.8, 0.86, 1.0), Color(0.8, 0.86, 1.0), 6, 3)
	_add_distant_block(Vector3(-13.5, 2.2, -12.5), Vector3(7, 4.4, 5))
	_add_distant_block(Vector3(13.5, 2.2, -12.5), Vector3(7, 4.4, 5))
	camera.look_at(Vector3(0, 3.5, -7))


func _add_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(64, 64)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Cobble"
	floor_mesh.mesh = plane
	floor_mesh.material_override = COBBLE
	floor_mesh.position = Vector3(0, -0.02, 0)
	diorama.add_child(floor_mesh)


func _add_facade() -> void:
	var stone := Color(0.4, 0.38, 0.35)
	var trim := Color(0.55, 0.47, 0.3)
	var roof := Color(0.23, 0.15, 0.11)
	var warm := Color(0.95, 0.72, 0.32)
	var glow := Color(1.0, 0.62, 0.22)
	var dark := Color(0.05, 0.045, 0.04)

	_mesh_box(Vector3(0, 3.6, -7.5), Vector3(13, 7.2, 4), stone)
	_mesh_roof(Vector3(0, 8.35, -7.5), Vector3(14.2, 3.0, 4.8), roof)
	_mesh_box(Vector3(0, 2.6, -4.85), Vector3(8.8, 0.5, 1.6), stone.darkened(0.15))
	_mesh_box(Vector3(0, 0.45, -4.4), Vector3(9.6, 0.5, 1.2), stone.darkened(0.2))
	_mesh_box(Vector3(0, 2.35, -5.44), Vector3(3.9, 4.9, 0.12), trim)
	_mesh_box(Vector3(0, 2.3, -5.38), Vector3(3.2, 4.4, 0.12), dark)
	for side in [-1.0, 1.0]:
		_mesh_box(Vector3(side * 2.9, 3.6, -5.44), Vector3(0.32, 6.4, 0.18), trim)
		_mesh_box(Vector3(side * 3.6, 5.4, -5.43), Vector3(1.5, 1.9, 0.1), warm, glow)
		_mesh_box(Vector3(side * 3.6, 3.2, -5.43), Vector3(1.2, 1.3, 0.1), warm, glow)
		# side wings
		_mesh_box(Vector3(side * 10.4, 2.4, -8.5), Vector3(7.4, 4.8, 4.5), stone)
		_mesh_roof(Vector3(side * 10.4, 5.5, -8.5), Vector3(8.2, 2.2, 5.0), roof)
		_mesh_box(Vector3(side * 10.4, 2.6, -6.2), Vector3(1.2, 1.7, 0.1), warm, glow)
		_mesh_box(Vector3(side * 8.7, 0.55, -4.9), Vector3(1.0, 0.12, 1.0), trim)


func _add_banner(x: float, cloth: Color) -> void:
	_mesh_box(Vector3(x, 6.6, -5.28), Vector3(1.2, 0.07, 0.07), Color(0.5, 0.38, 0.18))
	_mesh_box(Vector3(x, 5.78, -5.24), Vector3(0.86, 1.55, 0.07), cloth)
	var emblem := _mesh_box(Vector3(x, 5.8, -5.19), Vector3(0.22, 0.22, 0.03),
			cloth.lightened(0.45))
	emblem.rotation.z = PI * 0.25


func _add_torch(x: float, z: float) -> void:
	var torch = TORCH_SCENE.instantiate()
	torch.position = Vector3(x, 0, z)
	torch.scale = Vector3(1.5, 1.5, 1.5)
	diorama.add_child(torch)
	var light: OmniLight3D = torch.get_node("OmniLight3D")
	light.omni_range = 13.0
	light.light_energy = 2.1
	_torch_lights.append(light)


func _add_distant_block(position: Vector3, dims: Vector3) -> void:
	_mesh_box(position, dims, Color(0.16, 0.18, 0.24))
	_mesh_roof(position + Vector3(0, dims.y * 0.5 + 0.7, 0),
			Vector3(dims.x * 1.1, 1.6, dims.z * 1.1), Color(0.1, 0.11, 0.16))


func _add_sphere(position: Vector3, radius: float, color: Color, emission: Color,
		segments := 12, rings := 6) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = segments
	sphere.rings = rings
	var instance := MeshInstance3D.new()
	instance.mesh = sphere
	instance.material_override = ClassKit.make_material(color, emission)
	instance.position = position
	diorama.add_child(instance)


func _mesh_box(position: Vector3, dims: Vector3, color: Color,
		emission := Color.BLACK) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dims
	return _add_mesh(mesh, position, color, emission)


func _mesh_roof(position: Vector3, dims: Vector3, color: Color) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = dims
	return _add_mesh(mesh, position, color)


func _add_mesh(mesh: Mesh, position: Vector3, color: Color,
		emission := Color.BLACK) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.material_override = ClassKit.make_material(color, emission)
	diorama.add_child(instance)
	return instance
