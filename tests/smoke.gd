extends Node
## Headless verification of the Phase 0 loop.
## Run: godot --headless --path . res://tests/smoke.tscn
## Prints SMOKKE-free "SMOKE_RESULT: PASS/FAIL" and exits nonzero on failure.

var failures: Array[String] = []
var total := 0
var main  # main scene root, kept untyped so members resolve dynamically


func _ready() -> void:
	print("SMOKE_START")
	_watchdog()
	_run()


## Safety net: if a runtime error aborts _run() before it can quit, report a
## failure with exit code 1 instead of leaving the engine idling forever.
func _watchdog() -> void:
	await get_tree().create_timer(900.0).timeout
	print("SMOKE_RESULT: FAIL (watchdog: the run stalled before the report)")
	get_tree().quit(1)


func _check(cond: bool, label: String) -> void:
	total += 1
	if cond:
		print("  PASS  " + label)
	else:
		failures.append(label)
		print("  FAIL  " + label)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(6)

	var player: CharacterBody3D = main.player
	var dummy = main.dummy
	var hud = main.hud
	var cam: Camera3D = player.get_node("SpringArm3D/Camera3D")

	# --- spawn + camera ---
	_check(player.global_position.z > 0.0, "spawn in the town square (z > 0)")
	var local: Vector3 = player.to_local(cam.global_position)
	var to_player := (player.global_position + Vector3(0, 1.4, 0) - cam.global_position)
	print("  info  camera local pos = ", local)
	_check(local.z > 0.5, "camera sits behind the player")
	_check(-cam.global_transform.basis.z.dot(to_player.normalized()) > 0.5,
			"camera looks back at the player")
	_check(main.zone == "Town Square", "starts in the Town Square zone")
	_check(hud.zone_label.text == "Town Square", "HUD shows the starting zone")

	# --- movement ---
	var z0 := player.global_position.z
	Input.action_press("move_forward")
	await _frames(30)
	Input.action_release("move_forward")
	await _frames(2)
	_check(player.global_position.z < z0 - 1.0, "WASD moves the player")

	# --- mouse camera ---
	var yaw0 := player.rotation.y
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(200, 0)
	Input.parse_input_event(motion)
	await _frames(4)
	_check(absf(player.rotation.y - yaw0) > 0.01, "mouse rotates the camera")

	# --- enter arena: transition + opponent reset ---
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0, 0.85, -17.5)
	await _frames(5)
	_check(main.zone == "Combat Arena", "arena transition on entry")
	_check(hud.zone_label.text == "Combat Arena", "HUD zone label updates")
	_check(dummy.hp >= dummy.max_hp and not dummy.is_defeated, "opponent reset on entry")
	var warden = main.warden
	_check(warden.hp >= warden.max_hp and warden.state == 0, "warden reset on entry (IDLE at home)")

	# --- lock on ---
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(2.5, 0.85, -21.5)
	player.rotation.y = 0.0
	await _frames(3)
	Input.action_press("lock_on")
	await _frames(2)
	Input.action_release("lock_on")
	await _frames(2)
	_check(player.locked_target == dummy, "Q locks onto the training dummy")
	_check(hud.reticle.visible, "lock-on reticle visible on HUD")

	# --- fighter skill 1 (Cleave) on hotbar slot 1 ---
	var dummy_hp0: float = dummy.hp
	Input.action_press("hotbar_1")
	await _frames(3)
	Input.action_release("hotbar_1")
	await _frames(3)
	_check(dummy.hp <= dummy_hp0 - 44.0, "hotbar 1 cleave hits hard (45 dmg)")
	_check(player.skill1_cd > 5.0, "cleave enters its 6 s cooldown")
	var dummy_hp1: float = dummy.hp
	Input.action_press("hotbar_1")
	await _frames(3)
	Input.action_release("hotbar_1")
	await _frames(3)
	_check(dummy.hp == dummy_hp1, "cleave blocked while on cooldown")

	# --- basic attack until defeated ---
	var hp_before: float = dummy.hp
	for attempt in 10:
		if dummy.is_defeated:
			break
		Input.action_press("attack")
		await _frames(3)
		Input.action_release("attack")
		if not dummy.is_defeated:
			await _frames(34)
	_check(dummy.hp < hp_before, "basic attack damages the opponent")
	_check(hud.hp_bar.value >= 0.0, "player HUD stat bars wired")
	_check(dummy.is_defeated, "basic attack defeats the opponent")
	_check(main.kills == 1, "kill counted by the game manager")
	_check(hud.score_label.text.findn("Kills 1") >= 0, "HUD scoreboard updates")

	# --- warden duel: telegraphed strike, HP + poise damage, stagger ---
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0, 0.85, -27.9)
	player.rotation.y = 0.0
	await _frames(4)
	var hp_w0: float = player.hp
	var poise_w0: float = player.poise
	var wait0 := 480
	while wait0 > 0 and player.hp >= hp_w0 and not player.is_dead:
		await _frames(1)
		wait0 -= 1
	_check(player.hp < hp_w0, "warden strike damages the player")
	_check(player.poise < poise_w0, "warden strike drains poise")
	_check(hud.damage_flash.color.a > 0.0, "HUD damage flash fires on hit")

	# poise break -> stagger (set poise low, wait for the next strike)
	player.poise = 5.0
	var wait1 := 480
	while wait1 > 0 and player.stagger_time <= 0.0 and not player.is_dead:
		await _frames(1)
		wait1 -= 1
	_check(player.stagger_time > 0.0, "poise break staggers the player")
	var wait2 := 200
	while wait2 > 0 and player.stagger_time > 0.0:
		await _frames(1)
		wait2 -= 1
	_check(player.stagger_time <= 0.0, "stagger wears off")

	# lock the warden (clears the defeated dummy first) and land the cleave
	Input.action_press("lock_on")
	await _frames(2)
	Input.action_release("lock_on")
	await _frames(2)
	Input.action_press("lock_on")
	await _frames(2)
	Input.action_release("lock_on")
	await _frames(4)
	_check(player.locked_target == warden, "lock-on switches to the warden")
	var wait3 := 400
	while wait3 > 0 and player.skill1_cd > 0.0:
		await _frames(1)
		wait3 -= 1
	var w_hp0: float = warden.hp
	Input.action_press("hotbar_1")
	await _frames(3)
	Input.action_release("hotbar_1")
	await _frames(3)
	_check(warden.hp <= w_hp0 - 44.0, "cleave damages the warden")
	_check(player.stamina < 100.0, "cleave costs stamina")

	# --- death and respawn ---
	player.hp = 8.0
	var wait4 := 600
	while wait4 > 0 and not player.is_dead:
		await _frames(1)
		wait4 -= 1
	_check(player.is_dead, "warden strike defeats the player")
	_check(main.deaths == 1, "death counted by the game manager")
	_check(hud.score_label.text.findn("Deaths 1") >= 0, "HUD scoreboard shows the death")
	var wait5 := 400
	while wait5 > 0 and player.is_dead:
		await _frames(1)
		wait5 -= 1
	_check(not player.is_dead, "player respawns after the delay")
	_check(player.global_position.z > 0.0, "respawn returns to the town square")
	_check(player.hp >= player.max_hp, "respawn restores health")

	# --- return to square: loop reset ---
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0, 0.85, 8)
	player.rotation.y = 0.0
	await _frames(6)
	_check(main.zone == "Town Square", "returning resets the zone to Town Square")
	_check(hud.zone_label.text == "Town Square", "HUD zone label back to Town Square")
	_check(not dummy.is_defeated and dummy.hp >= dummy.max_hp, "opponent reset on return")
	_check(warden.hp >= warden.max_hp and warden.state == 0, "warden reset on return")
	_check(main.kills == 1, "score preserved across the loop")
	_check(main.deaths == 1, "death count preserved across the loop")

	# --- controls preserved after reset ---
	var z1 := player.global_position.z
	Input.action_press("move_forward")
	await _frames(25)
	Input.action_press("move_back")
	await _frames(2)
	Input.action_release("move_forward")
	Input.action_release("move_back")
	await _frames(2)
	_check(player.global_position.z < z1 - 0.5, "controls respond after the loop resets")

	# --- Phase 2: arena wave loop ---
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0, 0.85, -18)
	player.rotation.y = 0.0
	await _frames(6)
	_check(main.zone == "Combat Arena", "re-entering the arena starts a new loop")
	_check(main.wave == 1, "the loop restarts at wave 1")
	_check(not dummy.is_defeated and dummy.hp >= dummy.max_hp, "wave 1 restores the training dummy")
	_check(warden.hp >= warden.max_hp and warden.state == 0, "wave 1 restores the arena warden")
	_check(not hud.results_panel.visible, "results panel hidden at the start of a wave")
	_check(hud.wave_label.visible and hud.wave_label.text.findn("Wave 1") >= 0,
			"HUD shows the wave counter")

	# --- clear wave 1 -> results panel -> wave 2 spawns ---
	dummy.take_damage(99999.0)
	warden.take_damage(99999.0)
	await _frames(4)
	_check(main.kills == 3, "wave 1 kills are counted")
	_check(hud.results_panel.visible, "wave-clear results panel appears")
	_check(hud.results_title.text.findn("Wave 1 cleared") >= 0,
			"results panel names the cleared wave")
	_check(hud.results_body.text.findn("Kills 3") >= 0, "results panel reports the run so far")

	var wait_w2 := 400
	while wait_w2 > 0 and main.spawned_foes.size() < 2:
		await _frames(1)
		wait_w2 -= 1
	_check(main.spawned_foes.size() == 2, "wave 2 spawns two new foes")
	_check(main.wave == 2, "wave counter advances to 2")
	_check(not hud.results_panel.visible, "results panel clears when the next wave starts")
	_check(hud.wave_label.text.findn("Wave 2") >= 0, "HUD wave label follows the spawn")

	var harrier: Variant = null
	var bulwark: Variant = null
	for foe in main.spawned_foes:
		if foe.kind == 1:
			harrier = foe
		elif foe.kind == 2:
			bulwark = foe
	_check(harrier != null, "wave 2 includes the ranged harrier")
	_check(bulwark != null, "wave 2 includes the shielded bulwark")

	# --- bulwark shield: frontal block, backstab bypass, guard break ---
	harrier.global_position = Vector3(-8.0, 0.9, -33.5)
	harrier.home = harrier.global_position
	bulwark.aggro_range = 0.0  # hold still: the shield checks must be deterministic
	bulwark.global_position = Vector3(6.5, 0.9, -19.0)
	bulwark.home = bulwark.global_position
	bulwark.rotation.y = 0.0  # facing north (-Z), toward the player
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(6.5, 0.85, -22.0)
	player.rotation.y = 0.0
	await _frames(6)

	var b_hp0: float = bulwark.hp
	var b_guard0: float = bulwark.guard
	bulwark.take_damage(25.0)
	_check(absf((b_hp0 - bulwark.hp) - 6.25) < 0.01, "bulwark shield blocks most frontal damage")
	_check(bulwark.guard <= b_guard0 - 25.0, "blocking drains the shield guard")

	var behind: Vector3 = bulwark.global_position + bulwark.global_transform.basis.z * 2.0
	var b_hp1: float = bulwark.hp
	bulwark.take_damage(25.0, behind)
	_check(b_hp1 - bulwark.hp >= 24.0, "an attack from behind bypasses the shield")

	bulwark.guard = 1.0
	bulwark.take_damage(25.0)
	_check(bulwark.state == 5, "an empty guard breaks the bulwark's stance")
	_check(bulwark.guard <= 0.0, "guard is spent after the break")
	var b_hp3: float = bulwark.hp
	bulwark.take_damage(25.0)
	_check(b_hp3 - bulwark.hp >= 24.0, "a broken guard takes full damage")

	var wait_gb := 500
	while wait_gb > 0 and bulwark.state == 5:
		await _frames(1)
		wait_gb -= 1
	_check(bulwark.state != 5, "the bulwark recovers its stance")
	_check(bulwark.guard >= bulwark.guard_max - 0.01, "guard refills after the break")

	# --- harrier ranged duel ---
	bulwark.take_damage(99999.0)
	await _frames(3)
	_check(bulwark.state == 4 and bulwark.hp <= 0.0, "the bulwark topples when defeated")

	harrier.reset()  # full health, home, idle
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(-8.0, 0.85, -24.0)  # 9.5 m, clear LOS (no torch)
	player.rotation.y = 0.0
	await _frames(4)
	var p_hp0: float = player.hp
	var wait_shoot := 600
	while wait_shoot > 0 and player.hp >= p_hp0 and not player.is_dead:
		await _frames(1)
		wait_shoot -= 1
	_check(player.hp < p_hp0, "the harrier's bolt damages the player from range")

	# --- clear wave 2 -> wave 3 ---
	harrier.take_damage(99999.0)
	await _frames(4)
	_check(hud.results_panel.visible, "results panel returns after wave 2")
	_check(hud.results_title.text.findn("Wave 2 cleared") >= 0, "results panel names wave 2")

	var wait_w3 := 400
	while wait_w3 > 0 and main.spawned_foes.size() < 3:
		await _frames(1)
		wait_w3 -= 1
	_check(main.spawned_foes.size() == 3, "wave 3 spawns three foes")
	_check(main.wave == 3, "wave counter advances to 3")

	# --- clear wave 3 -> arena cleared, no wave 4 ---
	for foe in main.spawned_foes:
		foe.take_damage(99999.0)
	await _frames(4)
	_check(hud.results_panel.visible, "clearing the last wave reports the loop result")
	_check(hud.results_title.text.findn("Arena Cleared") >= 0,
			"final results panel says Arena Cleared")
	var wait_none := 200
	while wait_none > 0:
		await _frames(1)
		wait_none -= 1
	_check(main.wave == 3, "no wave 4 spawns after the arena is cleared")
	_check(main.spawned_foes.size() == 3, "no new foes appear once the loop ends")

	# --- leaving the arena cleans the loop up ---
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0, 0.85, 8)
	player.rotation.y = 0.0
	await _frames(6)
	_check(main.zone == "Town Square", "leaving the arena ends the loop")
	_check(main.wave == 0, "wave counter resets outside the arena")
	_check(main.spawned_foes.is_empty(), "spawned foes are cleared on exit")
	_check(not hud.results_panel.visible, "results panel closes on exit")
	_check(not hud.wave_label.visible, "wave label hides outside the arena")
	_check(not dummy.is_defeated and warden.state == 0, "placed opponents reset on exit")

	# ============ Phase 3: fighter class kit + champion lineup ============

	# --- class kit on the HUD ---
	_check(player.class_id == "fighter", "the player enters the world as the fighter")
	_check(hud.class_label.text == "FIGHTER", "HUD shows the class name above the skill bar")
	_check(hud.slot_names[0].text == "Cleave", "hotbar slot 1 is named Cleave")
	_check(hud.slot_names[1].text == "Second Wind", "hotbar slot 2 is named Second Wind")
	var locked_ok := true
	for i in range(2, 5):
		if hud.slot_names[i].text != "locked" or hud.slot_keys[i].text != "–":
			locked_ok = false
	_check(locked_ok, "slots 3-5 stay locked until their classes exist")

	# --- re-enter the arena for the class-kit combat checks ---
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0, 0.85, -18)
	player.rotation.y = 0.0
	await _frames(6)
	_check(main.zone == "Combat Arena", "class-kit checks run inside the arena")
	_check(main.wave == 1, "the wave loop restarts for the class-kit checks")

	# Stage the dummy and the warden inside one cleave arc, both stationary.
	warden.aggro_range = 0.0
	warden.global_position = Vector3(2.0, 0.9, -24.0)
	warden.home = warden.global_position
	dummy.global_position = Vector3(0.0, 0.9, -24.0)
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0, 0.85, -21.5)
	player.rotation.y = 0.0
	player.locked_target = null
	player.stamina = 100.0
	player.skill1_cd = 0.0
	await _frames(4)

	var d_hp0: float = dummy.hp
	var w_hp_arc: float = warden.hp
	Input.action_press("hotbar_1")
	await _frames(3)
	Input.action_release("hotbar_1")
	await _frames(3)
	_check(d_hp0 - dummy.hp >= 44.0, "cleave hits the foe straight ahead")
	_check(w_hp_arc - warden.hp >= 44.0, "cleave hits a second foe in the same arc")
	_check(player.skill1_cd > 5.0, "the cleave cooldown starts after the swing")
	_check(hud.slot_panels[0].modulate != Color.WHITE, "HUD slot 1 dims during the cooldown")

	# --- cleave is stamina-gated ---
	var wait_cd := 400
	while wait_cd > 0 and player.skill1_cd > 0.0:
		await _frames(1)
		wait_cd -= 1
	player.stamina = 10.0
	player._stamina_delay = 1.0  # freeze regen so the gate check is exact
	var d_hp_gate: float = dummy.hp
	Input.action_press("hotbar_1")
	await _frames(3)
	Input.action_release("hotbar_1")
	await _frames(3)
	_check(dummy.hp == d_hp_gate and player.stamina == 10.0, "cleave is gated by stamina")
	_check(player.skill1_cd == 0.0, "a blocked cleave never starts its cooldown")
	player.stamina = 100.0

	# --- fighter skill 2: Second Wind ---
	player.hp = 40.0
	Input.action_press("hotbar_2")
	await _frames(3)
	Input.action_release("hotbar_2")
	await _frames(3)
	_check(player.hp >= 74.0, "second wind heals the fighter")
	_check(player.skill2_cd > 15.0, "second wind enters its long cooldown")
	_check(hud.slot_keys[1].text != "2", "HUD slot 2 shows the countdown")
	var hp_s: float = player.hp
	Input.action_press("hotbar_2")
	await _frames(3)
	Input.action_release("hotbar_2")
	await _frames(3)
	_check(player.hp == hp_s and player.skill2_cd > 15.0,
			"second wind blocked while on cooldown")

	# --- weapon combo: two cuts, then the finisher ---
	player.locked_target = null
	player.combo_step = 0
	player.combo_timer = 0.0
	player._attack_cd = 0.0
	dummy.reset()
	var hit_sizes: Array = []
	for i in 3:
		while player._attack_cd > 0.0:
			await _frames(1)
		var before: float = dummy.hp
		Input.action_press("attack")
		await _frames(3)
		Input.action_release("attack")
		await _frames(3)
		hit_sizes.append(before - dummy.hp)
	_check(player.combo_step == 3, "the weapon combo reaches its third hit")
	_check(absf(hit_sizes[0] - 25.0) < 0.01, "the first combo hit is the basic attack (25 dmg)")
	_check(absf(hit_sizes[2] - 40.0) < 0.01, "the combo finisher hits harder (40 dmg)")
	var wait_combo := 120
	while wait_combo > 0 and player.combo_timer > 0.0:
		await _frames(1)
		wait_combo -= 1
	_check(player.combo_step == 0, "the combo chain resets after a pause")

	# --- the eight-champion lineup (concept image 2) ---
	var row = main.get_node("ChampionsRow")
	_check(row.figures.size() == 8, "the town square stages all eight champions")
	var expected_names := ["Bard", "Cleric", "Fighter", "Mage", "Ranger",
			"Rogue", "Summoner", "Tank"]
	var names_ok := true
	var plates_ok := true
	var weapons_ok := true
	var colors: Array = []
	for i in row.figures.size():
		var fig = row.figures[i]
		if fig.display_name != expected_names[i]:
			names_ok = false
		if fig.nameplate == null or str(fig.nameplate.text).findn(expected_names[i]) < 0:
			plates_ok = false
		var weapon_node = fig.get_node_or_null("Visual/Weapon")
		if weapon_node == null:
			weapons_ok = false
		else:
			var stack: Array = [weapon_node]
			var mesh_count := 0
			while not stack.is_empty():
				var part = stack.pop_back()
				for child in part.get_children():
					stack.append(child)
				if part is MeshInstance3D:
					if part.mesh == null:
						weapons_ok = false
					else:
						mesh_count += 1
			if mesh_count == 0:
				weapons_ok = false
		colors.append(fig.body_color)
	_check(names_ok, "lineup order matches concept image 2, left to right")
	_check(plates_ok, "every champion carries a readable nameplate")
	_check(weapons_ok, "every champion holds a built weapon prop")
	var colors_unique := true
	for i in colors.size():
		for j in range(i + 1, colors.size()):
			if colors[i] == colors[j]:
				colors_unique = false
	_check(colors_unique, "the eight champions use distinct body colours")
	var plinth = row.get_node_or_null("Plinth")
	var plinth_solid := false
	if plinth != null:
		for child in plinth.get_children():
			if child is CollisionShape3D:
				plinth_solid = true
	_check(plinth_solid, "the row stands on a solid plinth")
	_check(row.figures[2].get_node_or_null("Visual/Weapon/Greatsword") != null,
			"the fighter figure carries the greatsword")
	_check(row.figures[6].get_node_or_null("Visual/Ally") != null,
			"the summoner figure is joined by a spectral ally")
	_check(row.figures[7].get_node_or_null("Visual/Weapon/TowerShield") != null,
			"the tank figure raises the tower shield")

	# the standalone lineup scene (run it directly for a clean concept view)
	var lineup = load("res://scenes/lineup.tscn").instantiate()
	add_child(lineup)
	await _frames(2)
	_check(lineup.figures.size() == 8, "the standalone lineup scene stages the same eight")
	_check(lineup.get_node_or_null("Camera3D") != null,
			"the standalone scene frames itself with a camera")
	lineup.queue_free()

	# leave the loop clean: placed opponents back at their scene homes
	dummy.global_position = Vector3(2.5, 0.9, -25)
	dummy.reset()
	warden.aggro_range = 10.0
	warden.home = Vector3(0, 0.9, -30)
	warden.reset()

	# ============ Phase 4: character select + ranger class ============

	# --- the character-select screen (concept image 3) ---
	var select = load("res://scenes/character_select.tscn").instantiate()
	add_child(select)
	await _frames(4)
	_check(select.rows.size() == 8, "the select screen lists all eight archetypes")
	_check(select.selected_index == 2, "the picker opens on the Fighter (concept layout)")
	_check(select.figure != null and select.figure.display_name == "Fighter",
			"the dais shows the fighter figure")
	_check(select.get_node_or_null("ViewportBox/SubViewport/PreviewCamera") != null,
			"the dais is framed by its own preview camera")
	var slot_card = select.get_node("LeftPanel/Slot1/Slot1Name")
	_check(slot_card.text == "Rowan Vale", "the character slot card reads Rowan Vale")
	_check(select.enter_button.disabled == false, "Enter World is enabled for the fighter")

	# preview a locked archetype: the figure swaps but Enter World gates off
	select.select_class(0)  # Bard
	await _frames(2)
	_check(select.figure.display_name == "Bard", "picking the bard swaps the dais figure")
	_check(select.enter_button.disabled == true, "a locked archetype gates Enter World")
	_check(select.status_label.text.findn("not playable") >= 0,
			"the status line explains the lock")

	# pick the ranger and commit the choice the world reads on boot
	select.select_class(4)
	await _frames(2)
	_check(select.figure.display_name == "Ranger", "picking the ranger swaps the dais figure")
	_check(select.enter_button.disabled == false, "the ranger is playable")
	var committed: String = select.commit_selection()
	_check(committed == "ranger" and ClassKit.selected == "ranger",
			"Enter World would commit the ranger")
	select.queue_free()
	await _frames(2)

	# --- the ranger kit on the live world ---
	main.apply_class("ranger")
	await _frames(2)
	_check(player.class_id == "ranger", "the world swaps to the ranger")
	_check(hud.class_label.text == "RANGER", "the HUD relabels the class")
	_check(hud.slot_names[0].text == "Power Shot", "hotbar slot 1 becomes Power Shot")
	_check(hud.slot_names[1].text == "Tumble", "hotbar slot 2 becomes Tumble")
	_check(hud.hint_label.text.findn("shoot") >= 0, "the controls hint switches to bow controls")
	var sword = player.get_node("Visual/WeaponPivot/Sword")
	_check(not sword.visible, "the ranger sheathes the sword")
	var bow = player.get_node_or_null("Visual/WeaponPivot/Bow")
	_check(bow != null and bow.visible, "the ranger carries a bow")

	# --- basic arrow from beyond melee range (3.2 m): the clear x = -8 lane ---
	warden.aggro_range = 0.0
	warden.global_position = Vector3(-8.0, 0.9, -30.0)
	warden.home = warden.global_position
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(-8, 0.85, -21.5)
	player.rotation.y = 0.0
	player.locked_target = null
	await _frames(4)
	var w_hp_r: float = warden.hp
	Input.action_press("attack")
	await _frames(3)
	Input.action_release("attack")
	await _frames(60)  # bolt travel: 8.5 m at 20 m/s plus slack
	var arrow_hit: float = w_hp_r - warden.hp
	_check(arrow_hit >= 24.0, "a bow shot from 8 m damages the warden")
	_check(arrow_hit <= 26.0, "the basic arrow hits like a basic attack (25 dmg)")

	# --- ranger skill 1: Power Shot ---
	var w_hp_p: float = warden.hp
	player.stamina = 100.0
	Input.action_press("hotbar_1")
	await _frames(3)
	Input.action_release("hotbar_1")
	_check(player.skill1_cd > 4.0, "power shot enters its 5 s cooldown")
	_check(player.stamina <= 75.1, "power shot costs stamina")
	await _frames(60)
	_check(w_hp_p - warden.hp >= 49.0, "power shot hits hard (50 dmg)")
	_check(hud.slot_panels[0].modulate != Color.WHITE,
			"HUD slot 1 dims during the power-shot cooldown")

	# --- ranger skill 2: Tumble (evade dash) ---
	var tumble_from: float = player.global_position.z
	Input.action_press("hotbar_2")
	await _frames(4)
	Input.action_release("hotbar_2")
	_check(player.skill2_cd > 5.0, "tumble enters its cooldown")
	_check(player.evade_time > 0.0, "the tumble grants a brief evade window")
	await _frames(10)
	_check(player.global_position.z <= tumble_from - 1.5,
			"the tumble dashes the ranger forward")

	# --- back to the fighter: the swap is two-way ---
	main.apply_class("fighter")
	await _frames(2)
	_check(hud.slot_names[0].text == "Cleave", "switching back restores the fighter kit")
	_check(player.get_node("Visual/WeaponPivot/Sword").visible,
			"the fighter takes up the sword again")
	_check(hud.hint_label.text.findn("combo") >= 0,
			"the controls hint returns to the combo")

	# --- boot wiring: a fresh world reads the committed selection ---
	ClassKit.selected = "ranger"
	var world2 = load("res://scenes/main.tscn").instantiate()
	add_child(world2)
	await _frames(5)
	var player2 = world2.player
	var hud2 = world2.hud
	_check(player2.class_id == "ranger", "a fresh world boots as the committed ranger")
	_check(hud2.class_label.text == "RANGER", "the fresh world's HUD shows the ranger")
	_check(hud2.slot_names[0].text == "Power Shot",
			"the fresh world's hotbar shows the ranger kit")
	world2.queue_free()
	await _frames(4)
	ClassKit.selected = "fighter"

	# ============ Phase 5: title screen + front-end flow ============

	# --- the project boots on the title screen (concept image 1) ---
	_check(ProjectSettings.get_setting("application/run/main_scene")
			== "res://scenes/title_screen.tscn", "the project boots on the title screen")
	var title = load("res://scenes/title_screen.tscn").instantiate()
	title.auto_navigate = false
	add_child(title)
	await _frames(3)
	_check(title.title_label.text == "ASHES OF ALBION", "the title screen names the game")
	var menu_labels := [title.enter_button.text, title.character_button.text,
			title.settings_button.text, title.exit_button.text]
	_check(menu_labels == ["Enter World", "Character Select", "Settings", "Exit"],
			"the title menu offers Enter World / Character Select / Settings / Exit")
	_check(title.continue_label.text.findn("Fighter") >= 0,
			"the title screen names the last committed champion")

	# --- title actions route to the right scenes ---
	title.enter_world()
	_check(title.requested_scene == "res://scenes/main.tscn",
			"Enter World on the title screen opens the world")
	title.open_character_select()
	_check(title.requested_scene == "res://scenes/character_select.tscn",
			"Character Select opens the champion picker")

	# --- the settings panel ---
	_check(not title.settings_panel.visible, "settings start closed")
	title.open_settings()
	_check(title.settings_panel.visible, "Settings opens the options panel")
	title.volume_slider.value = 40.0
	_check(absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.4)) < 0.05,
			"the volume slider drives the master bus")
	title.volume_slider.value = 100.0
	title.close_settings()
	_check(not title.settings_panel.visible, "Back closes the settings panel")
	title.queue_free()
	await _frames(2)

	# --- Back from the picker returns to the title ---
	var select_back = load("res://scenes/character_select.tscn").instantiate()
	select_back.auto_navigate = false
	add_child(select_back)
	await _frames(3)
	_check(not select_back.back_button.disabled, "the picker's Back button is live")
	select_back.back_to_title()
	_check(select_back.requested_scene == "res://scenes/title_screen.tscn",
			"Back returns to the title screen")
	select_back.queue_free()
	await _frames(2)

	# --- in-world Esc menu: pause, resume and the way back out ---
	var pause = main.pause_menu
	pause.auto_navigate = false
	_check(not pause.is_open, "the world starts with its menu closed")
	pause.open()
	_check(pause.is_open and pause.root.visible, "the menu opens over the world")
	_check(get_tree().paused, "opening the menu pauses the world")
	pause.close()
	_check(not pause.is_open and not get_tree().paused, "Resume unpauses the world")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	get_viewport().push_input(esc)
	_check(pause.is_open, "the Esc key opens the menu")
	pause.go_to_character_select()
	_check(pause.requested_scene == "res://scenes/character_select.tscn",
			"the menu returns to character select")
	_check(not get_tree().paused and not pause.is_open,
			"leaving the run unpauses before the scene change")
	pause.open()
	pause.go_to_title()
	_check(pause.requested_scene == "res://scenes/title_screen.tscn",
			"the menu can also go back to the title screen")

	# ============ Phase 6: fighter skill tree ============
	SkillTreeData.reset_to_default()
	SkillTreeData.apply_to(player)
	var tree = load("res://scenes/skill_tree.tscn").instantiate()
	add_child(tree)
	await _frames(3)
	tree.open(player)
	_check(tree.is_open and tree.board.visible, "the skill tree board opens")
	_check(get_tree().paused, "the world pauses behind the skill tree")
	_check(tree.title_label.text == "Fighter Skill Tree", "the board names the fighter tree")
	_check(tree.buttons.size() == 11, "the tree stages every node")
	_check(SkillTreeData.rank_of("offensive") == 2, "Offensive Form starts at rank 2/3")
	_check(SkillTreeData.rank_of("cleave") == 1 and SkillTreeData.rank_of("fortify") == 1,
			"Cleave and Fortify start at rank 1/3")
	_check(SkillTreeData.points_available() == 2, "two skill points are available")
	_check(tree.points_label.text.findn("2") >= 0, "the points counter shows the pool")
	_check(tree.orbs.get_child_count() == 2, "two gold orbs mark the available points")
	_check(tree.rank_labels["cleave"].text == "Rank 1/3", "nodes carry rank pips")
	_check(tree.rank_labels["whirlwind"].text == "Locked", "Whirlwind is locked")
	_check(not SkillTreeData.can_rank("whirlwind"), "a locked node cannot be ranked")
	_check(not SkillTreeData.can_rank("armor_break") and not SkillTreeData.can_rank("bulwark"),
			"Armor Break and Bulwark are locked too")
	_check(tree.rail_hint.text.findn("Level 25") >= 0,
			"the Secondary Archetype rail gates at level 25")

	# spending feeds the live kit
	var cleave_before: float = player.cleave_damage
	_check(tree.spend("cleave"), "a point can be spent on Cleave")
	_check(SkillTreeData.rank_of("cleave") == 2, "Cleave reaches rank 2")
	_check(absf(player.cleave_damage - (cleave_before + 6.0)) < 0.01,
			"the rank feeds the live Cleave damage")
	_check(SkillTreeData.points_available() == 1, "the pool drains by one")
	_check(tree.rank_labels["cleave"].text == "Rank 2/3", "the rank pip updates")
	var wind_before: float = player.wind_heal
	_check(tree.spend("second_wind"), "Second Wind can be ranked")
	_check(absf(player.wind_heal - (wind_before + 8.0)) < 0.01,
			"the rank feeds the live Second Wind heal")
	_check(SkillTreeData.points_available() == 0, "the pool is empty")
	_check(not tree.spend("cleave"), "an empty pool blocks further ranks")
	_check(SkillTreeData.rank_of("cleave") == 2, "a blocked spend changes nothing")
	tree.reset_all()
	_check(SkillTreeData.points_available() == 8, "Reset refunds every point")
	_check(SkillTreeData.rank_of("offensive") == 0 and SkillTreeData.rank_of("cleave") == 0,
			"Reset clears the ranks")
	_check(absf(player.cleave_damage - 45.0) < 0.01, "Reset returns Cleave to its base damage")
	_check(absf(player.wind_heal - 35.0) < 0.01, "Reset returns Second Wind to its base heal")
	tree.close()
	_check(not tree.is_open and not get_tree().paused, "closing the board unpauses the world")
	tree.queue_free()
	await _frames(2)

	# pause-menu entry point
	_check(main.pause_menu.skills_button != null, "the pause menu offers the skill tree")
	main.pause_menu.open()
	main.pause_menu.skills_pressed.emit()
	_check(main.skill_tree.is_open, "Skills opens the tree from the pause menu")
	_check(not main.pause_menu.is_open, "the pause menu steps aside")
	main.skill_tree.close()
	await _frames(2)
	_check(not get_tree().paused, "closing from the menu unpauses the world")
	SkillTreeData.reset_to_default()
	SkillTreeData.apply_to(player)

	# --- report ---
	if failures.is_empty():
		print("SMOKE_RESULT: PASS — %d/%d" % [total, total])
	else:
		print("SMOKE_RESULT: FAIL (%d failed of %d)" % [failures.size(), total])
		for f in failures:
			print("  FAILED: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)
