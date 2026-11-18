extends CharacterBody3D
## Third-person player: camera-relative movement, spring-arm camera,
## lock-on, the Fighter class kit (weapon combo + Cleave + Second Wind) or
## the Ranger kit (bow shots + Power Shot + Tumble), HP/poise damage taken
## with stagger, and death -> respawn back in the square.

signal damaged(hp: float, max_hp: float, poise: float)
signal died

const BOLT_SCENE := preload("res://scenes/projectile.tscn")

@export var class_id := "fighter"  # ClassKit id; set from the character-select screen
@export var move_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.0025
@export var attack_damage := 25.0
@export var attack_range := 3.2
@export var attack_cooldown := 0.5
# Weapon combo: two quick cuts, then a heavier finisher that resets after a pause.
@export var combo_finisher := 40.0
@export var combo_window := 1.2
# Skill 1 - Cleave: an arc strike that hits every foe in front.
@export var cleave_damage := 45.0
@export var cleave_range := 4.5
@export var cleave_min_dot := 0.3
@export var cleave_stamina_cost := 30.0
@export var cleave_cooldown := 6.0
# Skill 2 - Second Wind: the fighter's self-sustain.
@export var wind_heal := 35.0
@export var wind_stamina := 25.0
@export var wind_cooldown := 18.0
# Skill 3 - the slot each class earns by clearing the arena (Progress).
# Fighter Whirlwind: a full-circle strike around the player.
@export var whirlwind_damage := 35.0
@export var whirlwind_range := 3.6
@export var whirlwind_stamina_cost := 40.0
@export var whirlwind_cooldown := 12.0
# Ranger Volley: three arrows in a fan.
@export var volley_damage := 20.0
@export var volley_spread := 0.16
@export var volley_stamina_cost := 35.0
@export var volley_cooldown := 10.0
# Ranger skill 1 - Power Shot: one long-range bolt.
@export var power_shot_damage := 50.0
@export var power_shot_poise := 30.0
@export var power_shot_stamina_cost := 25.0
@export var power_shot_cooldown := 5.0
# Ranger skill 2 - Tumble: a short evade dash with brief i-frames.
@export var tumble_cooldown := 7.0
@export var tumble_speed := 14.0
@export var tumble_time := 0.25
@export var tumble_evade := 0.4
@export var max_hp := 100.0
@export var max_stamina := 100.0
@export var max_poise := 100.0
@export var stagger_duration := 1.0
@export var respawn_delay := 2.5

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var weapon_pivot: Node3D = $Visual/WeaponPivot

var hp := 100.0
var stamina := 100.0
var poise := 100.0
var locked_target: Node3D = null
var stagger_time := 0.0
var skill1_cd := 0.0
var skill2_cd := 0.0
var skill3_cd := 0.0
var combo_step := 0
var combo_timer := 0.0
var dash_time := 0.0
var dash_dir := Vector3.ZERO
var evade_time := 0.0
var is_dead := false

var _attack_cd := 0.0
var _stamina_delay := 0.0
var _bow: Node3D = null
var camera_enabled := true
var _skip_attack_once := false  # the click that recaptures the mouse must not also swing
var _respawn_timer := 0.0
var _spawn_position := Vector3.ZERO
var _hurt_tween: Tween = null
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	hp = max_hp
	stamina = max_stamina
	poise = max_poise
	add_to_group("player")
	_spawn_position = global_position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and camera_enabled:
		rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotation.x = clampf(
			spring_arm.rotation.x - event.relative.y * mouse_sensitivity, -1.1, 0.5)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if camera_enabled:
			# first Esc: release the mouse (camera look off)
			camera_enabled = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			# second Esc (mouse already up): walk back up the front-end flow
			get_tree().change_scene_to_file("res://scenes/character_select.tscn")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and not camera_enabled and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		# clicking the open world recaptures the mouse (HUD clicks never reach here)
		camera_enabled = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_skip_attack_once = true


func _physics_process(delta: float) -> void:
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_stamina_delay = maxf(_stamina_delay - delta, 0.0)
	skill1_cd = maxf(skill1_cd - delta, 0.0)
	skill2_cd = maxf(skill2_cd - delta, 0.0)
	skill3_cd = maxf(skill3_cd - delta, 0.0)
	stagger_time = maxf(stagger_time - delta, 0.0)
	combo_timer = maxf(combo_timer - delta, 0.0)
	evade_time = maxf(evade_time - delta, 0.0)
	dash_time = maxf(dash_time - delta, 0.0)
	if combo_timer <= 0.0:
		combo_step = 0  # the combo drops if you stop swinging

	# Lock-on: face the target while it is held.
	if locked_target != null and is_instance_valid(locked_target):
		var to_target := locked_target.global_position - global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.01:
			var desired_yaw := atan2(-to_target.x, -to_target.z)
			rotation.y = lerp_angle(rotation.y, desired_yaw, minf(10.0 * delta, 1.0))
	else:
		locked_target = null

	if is_dead:
		_respawn_timer -= delta
		_brake(delta)
		_apply_gravity(delta, false)
		move_and_slide()
		if _respawn_timer <= 0.0:
			respawn()
		return

	if stagger_time > 0.0:
		# Staggered: movement, attacks and skills are locked out briefly.
		_brake(delta)
		_apply_gravity(delta, false)
		move_and_slide()
		return

	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()

	if dash_time > 0.0:
		# Tumble: a committed evade dash along the facing direction.
		velocity.x = dash_dir.x * tumble_speed
		velocity.z = dash_dir.z * tumble_speed
		_apply_gravity(delta, false)
		move_and_slide()
	else:
		var sprinting := Input.is_action_pressed("sprint") and input_vec != Vector2.ZERO and stamina > 0.0
		var speed := sprint_speed if sprinting else move_speed
		if sprinting:
			stamina = maxf(stamina - 18.0 * delta, 0.0)
			_stamina_delay = 1.0
		elif _stamina_delay <= 0.0:
			stamina = minf(stamina + 12.0 * delta, max_stamina)

		var target_vel := direction * speed
		velocity.x = lerpf(velocity.x, target_vel.x, minf(12.0 * delta, 1.0))
		velocity.z = lerpf(velocity.z, target_vel.z, minf(12.0 * delta, 1.0))
		_apply_gravity(delta, true)
		move_and_slide()

	if Input.is_action_just_pressed("attack"):
		if _skip_attack_once:
			_skip_attack_once = false
		else:
			attack()
	if Input.is_action_just_pressed("hotbar_1"):
		use_skill_1()
	if Input.is_action_just_pressed("hotbar_2"):
		use_skill_2()
	if Input.is_action_just_pressed("hotbar_3"):
		use_skill_3()
	if Input.is_action_just_pressed("lock_on"):
		toggle_lock_on()


func _apply_gravity(delta: float, allow_jump: bool) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif allow_jump and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity


func _brake(delta: float) -> void:
	velocity.x = lerpf(velocity.x, 0.0, minf(14.0 * delta, 1.0))
	velocity.z = lerpf(velocity.z, 0.0, minf(14.0 * delta, 1.0))


func take_damage(amount: float, poise_amount: float = 30.0) -> void:
	if is_dead:
		return
	if evade_time > 0.0:
		return  # mid-Tumble: the ranger phases through the hit
	hp = maxf(hp - amount, 0.0)
	poise = maxf(poise - poise_amount, 0.0)
	_flash_hurt()
	var offset := Vector3(randf_range(-0.3, 0.3), 1.7, randf_range(-0.2, 0.2))
	_spawn_damage_number(global_position + offset, int(amount), Color(0.95, 0.3, 0.25))
	damaged.emit(hp, max_hp, poise)
	if hp <= 0.0:
		die()
	elif poise <= 0.0:
		stagger()


func stagger() -> void:
	stagger_time = stagger_duration
	poise = max_poise  # poise refills on break: no perma-stunlock
	damaged.emit(hp, max_hp, poise)


func die() -> void:
	if is_dead:
		return
	is_dead = true
	stagger_time = 0.0
	locked_target = null
	velocity = Vector3.ZERO
	_respawn_timer = respawn_delay
	died.emit()
	var tween := create_tween()
	tween.tween_property($Visual, "rotation", Vector3(-PI * 0.5, 0.0, 0.0), 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func respawn() -> void:
	is_dead = false
	hp = max_hp
	stamina = max_stamina
	poise = max_poise
	stagger_time = 0.0
	_respawn_timer = 0.0
	global_position = _spawn_position
	velocity = Vector3.ZERO
	rotation.y = 0.0
	$Visual.rotation = Vector3.ZERO
	$Visual.scale = Vector3.ONE
	damaged.emit(hp, max_hp, poise)


func _flash_hurt() -> void:
	if _hurt_tween != null and _hurt_tween.is_valid():
		_hurt_tween.kill()
	_hurt_tween = create_tween()
	_hurt_tween.tween_property($Visual, "scale", Vector3(1.07, 1.07, 1.07), 0.05)
	_hurt_tween.tween_property($Visual, "scale", Vector3.ONE, 0.12)


func attack() -> void:
	## Basic attack. Melee classes chain a weapon combo (two quick cuts, then
	## a heavier finisher); the ranger looses arrows instead. Each hit
	## refreshes the combo window; letting it lapse starts the chain over.
	if _attack_cd > 0.0 or is_dead or stagger_time > 0.0:
		return
	_attack_cd = attack_cooldown
	if ClassKit.is_ranged(class_id):
		_swing_weapon(false)  # draw-and-loose read on the bow
		_shoot(attack_damage, 20.0)
		return
	combo_timer = combo_window
	combo_step = combo_step % 3 + 1
	var damage := attack_damage if combo_step < 3 else combo_finisher
	_swing_weapon(combo_step == 3)
	var target := _find_attack_target()
	if target != null and target.has_method("take_damage"):
		# Pass the strike origin so shields can tell front hits from back hits.
		target.call("take_damage", damage, global_position)
		var offset := Vector3(randf_range(-0.3, 0.3), 1.6, randf_range(-0.2, 0.2))
		var number_color := Color(1.0, 0.55, 0.2) if combo_step == 3 \
				else Color(1.0, 0.85, 0.3)
		_spawn_damage_number(target.global_position + offset, int(damage), number_color)


func use_skill_1() -> void:
	## Slot 1 by class: the ranger's Power Shot (a long-range bolt) or the
	## fighter's Cleave (an arc that hits every foe in front). Both are
	## stamina-gated and cooldown-gated.
	if is_dead or stagger_time > 0.0 or skill1_cd > 0.0:
		return
	if ClassKit.is_ranged(class_id):
		if stamina < power_shot_stamina_cost:
			return
		stamina -= power_shot_stamina_cost
		_stamina_delay = 1.2
		skill1_cd = power_shot_cooldown
		_swing_weapon(false)
		_shoot(power_shot_damage, power_shot_poise)
		return
	if stamina < cleave_stamina_cost:
		return
	stamina -= cleave_stamina_cost
	_stamina_delay = 1.2
	skill1_cd = cleave_cooldown
	_swing_weapon(true)
	for target in _arc_targets(cleave_range, cleave_min_dot):
		# Pass the strike origin so shields can tell front hits from back hits.
		target.call("take_damage", cleave_damage, global_position)
		var offset := Vector3(randf_range(-0.3, 0.3), 1.7, randf_range(-0.2, 0.2))
		_spawn_damage_number(target.global_position + offset, int(cleave_damage),
				Color(1.0, 0.55, 0.2))


func use_skill_2() -> void:
	## Slot 2 by class: the ranger's Tumble (evade dash, brief i-frames) or
	## the fighter's Second Wind (recover health and stamina).
	if is_dead or stagger_time > 0.0 or skill2_cd > 0.0:
		return
	if ClassKit.is_ranged(class_id):
		skill2_cd = tumble_cooldown
		var facing := -global_transform.basis.z
		facing.y = 0.0
		dash_dir = facing.normalized()
		if dash_dir.length_squared() < 0.01:
			dash_dir = Vector3.FORWARD
		dash_time = tumble_time
		evade_time = tumble_evade
		return
	if hp >= max_hp:
		return
	skill2_cd = wind_cooldown
	var healed := minf(wind_heal, max_hp - hp)
	hp += healed
	stamina = minf(stamina + wind_stamina, max_stamina)
	_stamina_delay = 0.4
	damaged.emit(hp, max_hp, poise)
	_spawn_damage_number(global_position + Vector3(0, 1.9, 0), int(healed),
			Color(0.4, 0.95, 0.5))


func use_skill_3() -> void:
	## Slot 3, earned per class: the fighter's Whirlwind (a strike all the way
	## around the player) or the ranger's Volley (a three-arrow fan). Stays
	## inert until Progress unlocks it for this class.
	if is_dead or stagger_time > 0.0 or skill3_cd > 0.0:
		return
	if not Progress.is_slot_unlocked(class_id):
		return
	if ClassKit.is_ranged(class_id):
		if stamina < volley_stamina_cost:
			return
		stamina -= volley_stamina_cost
		_stamina_delay = 1.2
		skill3_cd = volley_cooldown
		_swing_weapon(true)
		for spread in [-volley_spread, 0.0, volley_spread]:
			_shoot(volley_damage, 20.0, float(spread))
		return
	if stamina < whirlwind_stamina_cost:
		return
	stamina -= whirlwind_stamina_cost
	_stamina_delay = 1.2
	skill3_cd = whirlwind_cooldown
	_swing_weapon(true)
	for target in _arc_targets(whirlwind_range, -1.0):  # -1.0 dot: the whole circle
		target.call("take_damage", whirlwind_damage, global_position)
		var offset := Vector3(randf_range(-0.3, 0.3), 1.7, randf_range(-0.2, 0.2))
		_spawn_damage_number(target.global_position + offset, int(whirlwind_damage),
				Color(1.0, 0.7, 0.25))


## Fire one bolt from chest height: aims at the locked target when there is
## one, otherwise straight along the facing direction. Friendly to foes.
## `spread` fans the shot off the aim by that many radians around Y.
func _shoot(dmg: float, poise: float, spread: float = 0.0) -> void:
	var muzzle := global_position + Vector3(0, 0.5, 0)
	var dir := -global_transform.basis.z
	if locked_target != null and is_instance_valid(locked_target):
		var aim: Vector3 = locked_target.global_position + Vector3(0, 0.4, 0) - muzzle
		if aim.length() > 0.01:
			dir = aim.normalized()
	if not is_zero_approx(spread):
		dir = dir.rotated(Vector3.UP, spread)
	var bolt := BOLT_SCENE.instantiate()
	var world: Node = get_tree().get_first_node_in_group("world")
	if world == null:
		world = get_tree().current_scene
	world.add_child(bolt)
	bolt.global_position = muzzle + dir * 0.6
	bolt.call("launch", dir, dmg, poise, get_rid(), true)


## Apply a class from the character-select screen: kit id, weapon visuals
## and a clean cooldown slate. main._ready calls this with ClassKit.selected.
func setup_class(id: String) -> void:
	class_id = id
	skill1_cd = 0.0
	skill2_cd = 0.0
	skill3_cd = 0.0
	combo_step = 0
	combo_timer = 0.0
	dash_time = 0.0
	evade_time = 0.0
	var ranged := ClassKit.is_ranged(class_id)
	weapon_pivot.get_node("Sword").visible = not ranged
	weapon_pivot.get_node("Guard").visible = not ranged
	if ranged:
		_ensure_bow()
		_bow.visible = true
	elif _bow != null:
		_bow.visible = false


## The ranger's bow, built once from primitives the first time it is needed.
func _ensure_bow() -> void:
	if _bow != null:
		return
	_bow = Node3D.new()
	_bow.name = "Bow"
	weapon_pivot.add_child(_bow)
	var wood := ClassKit.make_material(Color(0.45, 0.33, 0.2))
	var string_mat := ClassKit.make_material(Color(0.9, 0.88, 0.8))
	_bow_box(Vector3(0.05, 1.3, 0.05), wood, Vector3(0, 0.1, -0.5), Vector3.ZERO)
	_bow_box(Vector3(0.04, 0.55, 0.04), wood, Vector3(0, 0.72, -0.44), Vector3(-0.35, 0, 0))
	_bow_box(Vector3(0.04, 0.55, 0.04), wood, Vector3(0, -0.5, -0.44), Vector3(0.35, 0, 0))
	_bow_box(Vector3(0.012, 1.25, 0.012), string_mat, Vector3(0, 0.1, -0.36), Vector3.ZERO)


func _bow_box(size: Vector3, mat: Material, pos: Vector3, rot: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.rotation = rot
	_bow.add_child(node)


## Every live attackable foe inside the arc: in range and within the cone
## measured from the direction the player faces.
func _arc_targets(max_range: float, min_dot: float) -> Array:
	var found: Array = []
	var facing := -global_transform.basis.z
	facing.y = 0.0
	facing = facing.normalized()
	for node in get_tree().get_nodes_in_group("attackable"):
		if not (node is Node3D) or not node.has_method("take_damage"):
			continue
		if _is_down(node):
			continue
		var to_target: Vector3 = node.global_position - global_position
		to_target.y = 0.0
		var dist: float = to_target.length()
		if dist > max_range or dist < 0.001:
			continue
		if facing.dot(to_target / dist) >= min_dot:
			found.append(node)
	return found


## Defeated targets are skipped so a cleave never prints damage on a corpse.
func _is_down(node: Node) -> bool:
	var defeated: Variant = node.get("is_defeated")
	if defeated != null:
		return bool(defeated)
	var state_value: Variant = node.get("state")
	if state_value != null:
		return int(state_value) == 4  # foe.gd State.DOWN
	return false


func toggle_lock_on() -> void:
	if locked_target != null and is_instance_valid(locked_target):
		locked_target = null
		return
	var nearest: Node3D = null
	var nearest_dist := 25.0
	for node in get_tree().get_nodes_in_group("attackable"):
		if not (node is Node3D) or not node.has_method("take_damage"):
			continue
		var dist := global_position.distance_to(node.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = node
	locked_target = nearest


func _find_attack_target() -> Node3D:
	if locked_target != null and is_instance_valid(locked_target) \
			and locked_target.has_method("take_damage") and _in_reach(locked_target):
		return locked_target
	var best: Node3D = null
	var best_dist := attack_range
	for node in get_tree().get_nodes_in_group("attackable"):
		if not (node is Node3D) or not node.has_method("take_damage"):
			continue
		var dist := global_position.distance_to(node.global_position)
		if dist < best_dist and _facing(node):
			best = node
			best_dist = dist
	return best


func _facing(target: Node3D) -> bool:
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.0001:
		return false
	return -global_transform.basis.z.dot(to_target.normalized()) > 0.35


func _in_reach(target: Node3D) -> bool:
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var dist := to_target.length()
	if dist > attack_range + 0.5 or dist < 0.001:
		return false
	return -global_transform.basis.z.dot(to_target.normalized()) > 0.2


func _swing_weapon(wide: bool = false) -> void:
	## The cleave and the combo finisher use a wider arc than a basic cut.
	var arc := 1.3 if wide else 0.7
	weapon_pivot.rotation = Vector3(0, -arc - 0.2, 0)
	var tween := create_tween()
	tween.tween_property(weapon_pivot, "rotation", Vector3(0, arc, 0), 0.16) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(weapon_pivot, "rotation", Vector3(0, -0.4, 0), 0.2)


func _spawn_damage_number(world_pos: Vector3, amount: int, number_color: Color = Color(1.0, 0.85, 0.3)) -> void:
	var label := Label3D.new()
	label.text = str(amount)
	label.font_size = 64
	label.outline_size = 14
	label.modulate = number_color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var world: Node = get_tree().get_first_node_in_group("world")
	if world == null:
		world = get_tree().current_scene
	world.add_child(label)
	label.global_position = world_pos
	var tween := label.create_tween()
	tween.tween_property(label, "position", label.position + Vector3(0, 1.2, 0), 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)
