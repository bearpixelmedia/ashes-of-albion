class_name ElectionKit
## The mayoral election lifecycle, shared by every Town Hall instance and saved
## to user://election.json. One cycle: the ballot opens with Ashford's opening
## tallies -> each citizen casts one vote, after which the ballot locks -> the
## 24 h clock (a Unix stamp, so it runs while the game is closed) expires -> the
## tally resolves, a level count resolving as a tie -> the results name the
## winner and the incumbent -> the next cycle opens, the incumbent carrying a
## one-vote advantage. A winner's mandate is sealed into MandateKit; a tie seals
## nothing, so the sitting mayor keeps office.

const OPEN := "open"
const RESULTS := "results"

const CANDIDATES: Array[Dictionary] = [
	{"name": "Aveline", "role": "Divine"},
	{"name": "Merrin", "role": "Economic"},
	{"name": "Garrick", "role": "Military"},
	{"name": "Ilyra", "role": "Scientific"},
]
const BALLOT_SECONDS := 86400.0
## Opening tallies of a fresh Ashford race. The incumbent carries +1 next cycle.
const OPENING_TALLIES := [4, 3, 2, 1]

## Overridable so the headless suite never touches the player's real election.
static var path := "user://election.json"

static var loaded := false
static var phase := OPEN
static var cycle := 1
static var incumbent := -1  # index of the sitting mayor, -1 before the first count
static var vote := -1  # this cycle's cast ballot, -1 until the citizen votes
static var votes: Array[int] = []
static var ballot_end := 0.0  # Unix stamp the count opens at
static var result: Dictionary = {}


static func now() -> float:
	return Time.get_unix_time_from_system()


## Read the saved election once per session; a fresh session opens election I.
static func ensure_loaded() -> void:
	if loaded:
		return
	loaded = true
	var data = null
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		cycle = 0
		incumbent = -1
		begin_cycle()
		return
	phase = str(data.get("phase", OPEN))
	cycle = maxi(1, int(data.get("cycle", 1)))
	incumbent = clampi(int(data.get("incumbent", -1)), -1, CANDIDATES.size() - 1)
	vote = clampi(int(data.get("vote", -1)), -1, CANDIDATES.size() - 1)
	ballot_end = float(data.get("ballot_end", 0.0))
	votes = []
	var saved: Array = data.get("votes", [])
	for i in CANDIDATES.size():
		votes.append(int(saved[i]) if i < saved.size() else int(OPENING_TALLIES[i]))
	if ballot_end <= 0.0:
		ballot_end = now() + BALLOT_SECONDS
	var leaders: Array[int] = []
	for value in data.get("leaders", []):
		leaders.append(int(value))
	result = {
		"cycle": cycle,
		"tied": bool(data.get("tied", false)),
		"winner": int(data.get("winner", -1)),
		"leaders": leaders,
		"top": int(data.get("top", 0)),
		"votes": votes.duplicate(),
	}
	if incumbent >= 0:
		MandateKit.apply(CANDIDATES[incumbent])  # the mayor still rules after a relaunch
	save()


static func save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"phase": phase,
		"cycle": cycle,
		"incumbent": incumbent,
		"vote": vote,
		"votes": votes,
		"ballot_end": ballot_end,
		"winner": int(result.get("winner", -1)),
		"tied": bool(result.get("tied", false)),
		"leaders": result.get("leaders", []),
		"top": int(result.get("top", 0)),
	}, "\t") + "\n")


## Drop the in-memory copy and read the file again — what a relaunch does.
static func reload_from_disk() -> void:
	loaded = false
	phase = OPEN
	cycle = 1
	incumbent = -1
	vote = -1
	votes = []
	ballot_end = 0.0
	result = {}
	ensure_loaded()


## A brand-new session: no mayor, election I, a fresh 24 h ballot.
static func reset() -> void:
	loaded = true
	phase = OPEN
	cycle = 0
	incumbent = -1
	vote = -1
	votes = []
	ballot_end = 0.0
	result = {}
	begin_cycle()


## Open the next election: the incumbent keeps a one-vote opening advantage.
static func begin_cycle() -> void:
	loaded = true
	phase = OPEN
	cycle += 1
	vote = -1
	result = {}
	votes = []
	for i in CANDIDATES.size():
		votes.append(int(OPENING_TALLIES[i]) + (1 if i == incumbent else 0))
	ballot_end = now() + BALLOT_SECONDS
	save()


static func is_open() -> bool:
	ensure_loaded()
	return phase == OPEN


static func remaining() -> float:
	ensure_loaded()
	if phase != OPEN or ballot_end <= 0.0:
		return 0.0
	return maxf(0.0, ballot_end - now())


static func is_expired() -> bool:
	return is_open() and remaining() <= 0.0


## Cast the citizen's one ballot of this election. Returns false when the ballot
## is closed or already cast — the lockout lives here, not in the screen.
static func cast_vote(index: int) -> bool:
	ensure_loaded()
	if phase != OPEN or vote >= 0 or index < 0 or index >= votes.size():
		return false
	votes[index] += 1
	vote = index
	save()
	return true


## The clock has run out: count the tally right now. Safe to call once a cycle.
static func maybe_resolve() -> bool:
	ensure_loaded()
	if not is_expired():
		return false
	resolve()
	return true


## Count the ballot: the top tally wins, a level top is a tie and elects nobody.
static func resolve() -> Dictionary:
	ensure_loaded()
	if phase != OPEN:
		return result
	phase = RESULTS
	ballot_end = now()
	var top := 0
	for count in votes:
		top = maxi(top, count)
	var leaders: Array[int] = []
	for i in votes.size():
		if votes[i] == top:
			leaders.append(i)
	var tied := leaders.size() > 1
	var winner := -1 if tied else leaders[0]
	if winner >= 0:
		incumbent = winner
		MandateKit.apply(CANDIDATES[winner])
	result = {
		"cycle": cycle,
		"tied": tied,
		"winner": winner,
		"leaders": leaders,
		"top": top,
		"votes": votes.duplicate(),
	}
	save()
	return result


## The sitting mayor's roster entry, or {} before the first count.
static func incumbent_candidate() -> Dictionary:
	ensure_loaded()
	if incumbent < 0 or incumbent >= CANDIDATES.size():
		return {}
	return CANDIDATES[incumbent]
