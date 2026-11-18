extends CharacterBody3D
## Arena foe: one state machine drives three encounter variants - the melee
## warden (Phase 1), the ranged harrier and the shielded bulwark. All chase
## the player while they share the arena, telegraph their strike, topple when
## defeated and reset on the square <-> arena transition.

signal defeated
signal health_changed(hp: float, max_hp: float)

enum FoeKind { MELEE, RANGED, SHIELDED }
enum State { IDLE, CHASE, WINDUP, RECOVER, DOWN, GUARD_BREAK }

const BAR_WIDTH := 1.4

@export var kind: FoeKind = FoeKind.MELEE
@export var max_hp := 120.0
@export var move_speed := 2.6
@export var aggro_range := 10.0
@export var attack_range := 2.4
@export var windup_time := 0.7
@export var recover_time := 1.4
@export var attack_damage := 18.0
@export var poise_damage := 35.0
## Combat flag over the head and in the HUD target frame (see CombatFlags).
@export var combat_flag: String = "combatant"

# Ranged variant (harrier): holds a preferred band and fires bolts.
@export var shoot_range := 14.0
@export var preferred_min := 7.0
@export var attack_cooldown := 2.2
@export var projectile_damage := 12.0
@export var projectile_poise := 16.0
@export var projectile_scene: PackedScene

# Shielded variant (bulwark): frontal blocks drain a guard meter instead of
# health; an empty guard opens a staggered vulnerability window.
@export var guard_max := 100.0
@export var shield_reduction := 0.75
@export var guard_break_time := 3.0

@onready var visual: Node3D = $Visual
@onready var weapon_pivot: Node3D = $Visual/WeaponPivot
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var health_bar: Node3D = $HealthBar
@onready var bar_fill: MeshInstance3D = $HealthBar/BarFill
@onready var telegraph: Label3D = $Telegraph

var hp := 120.0
var guard := 100.0
var state: State = State.IDLE
var home := Vector3.ZERO
var combat_name := ""
var flag_chip: Node3D = null
var _timer := 0.0
var _attack_cd := 0.0
var _telegraph_size := 72
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _bar_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("attackable")
	var plate := get_node_or_null("HealthBar/NameLabel") as Label3D
	combat_name = plate.text if plate != null else name
	flag_chip = CombatFlags.attach_chip(self, combat_flag, 3.15)
	home = global_position
	_telegraph_size = telegraph.font_size
	_bar_material = bar_fill.get_surface_override_material(0).duplicate() as StandardMaterial3D
	bar_fill.set_surface_override_material(0, _bar_material)
	reset()


func reset() -> void:
	hp = max_hp
	guard = guard_max
	state = State.IDLE
	_timer = 0.0
	_attack_cd = attack_cooldown
	global_position = home
	velocity = Vector3.ZERO
	rotation = Vector3.ZERO
	scale = Vector3.ONE
	collision_shape.set_deferred("disabled", false)
	health_bar.visible = true
	telegraph.visible = false
	telegraph.text = "!"
	telegraph.font_size = _telegraph_size
	visual.rotation = Vector3.ZERO
	weapon_pivot.rotation = Vector3(0, -0.4, 0)
	flag_chip.visible = true
	_update_bar()
	health_changed.emit(hp, max_hp)


## from_pos is where the hit came from (Vector3.INF when unknown). The
## bulwark's shield only covers frontal hits; attacks from behind bypass it.
func take_damage(amount: float, from_pos: Vector3 = Vector3.INF) -> void:
	if state == State.DOWN:
		return
	var blocked := kind == FoeKind.SHIELDED and state != State.GUARD_BREAK \
			and guard > 0.0 and _is_frontal(from_pos)
	var final_amount := amount
	if blocked:
		final_amount = amount * (1.0 - shield_reduction)
		guard = maxf(guard - amount, 0.0)
		if guard <= 0.0:
			_enter_guard_break()
	hp = maxf(hp - final_amount, 0.0)
	_update_bar()
	_flash()
	health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_go_down()


func _is_frontal(from_pos: Vector3) -> bool:
	if not from_pos.is_finite():
		return true  # unknown origin: treat as a frontal hit (fair default)
	var to_attacker := from_pos - global_position
	to_attacker.y = 0.0
	if to_attacker.length_squared() < 0.0001:
		return true
	return -global_transform.basis.z.dot(to_attacker.normalized()) > 0.0


func _enter_guard_break() -> void:
	state = State.GUARD_BREAK
	_timer = guard_break_time
	velocity = Vector3.ZERO
	telegraph.text = "BROKEN"
	telegraph.font_size = 56
	telegraph.visible = true
	weapon_pivot.rotation = Vector3(0.9, -0.4, 0)


func _go_down() -> void:
	state = State.DOWN
	telegraph.visible = false
	flag_chip.visible = false  # a fallen combatant stops advertising its flag
	collision_shape.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	var tween := create_tween()
	tween.tween_property(visual, "rotation", Vector3(-PI * 0.45, 0.0, 0.0), 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	defeated.emit()


func _physics_process(delta: float) -> void:
	if state == State.DOWN:
		return
	_attack_cd = maxf(_attack_cd - delta, 0.0)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	var target := _nearest_player()
	var to_target := Vector3.ZERO
	var dist := 999.0
	if target != null:
		to_target = target.global_position - global_position
		to_target.y = 0.0
		dist = to_target.length()

	match state:
		State.IDLE:
			if target != null and dist <= aggro_range:
				state = State.CHASE
			else:
				_walk_home(delta)
		State.CHASE:
			if target == null or dist > aggro_range:
				state = State.IDLE
			elif kind == FoeKind.RANGED:
				_ranged_step(to_target, dist, delta)
			elif dist <= attack_range:
				_enter_windup(to_target)
			else:
				_face(to_target, delta)
				_move_toward(to_target.normalized() * move_speed, delta)
		State.WINDUP:
			_timer -= delta
			velocity.x = 0.0
			velocity.z = 0.0
			if target == null:
				_cancel_windup()
			elif _timer <= 0.0:
				_telegraph_off()
				if kind == FoeKind.RANGED:
					_fire(target)
					_attack_cd = attack_cooldown
				else:
					_strike(target, dist)
				state = State.RECOVER
				_timer = recover_time
				var recover_tw := create_tween()
				recover_tw.tween_property(weapon_pivot, "rotation", Vector3(0, -0.4, 0), 0.3)
		State.RECOVER:
			_timer -= delta
			velocity.x = 0.0
			velocity.z = 0.0
			if _timer <= 0.0:
				state = State.CHASE
		State.GUARD_BREAK:
			_timer -= delta
			velocity.x = 0.0
			velocity.z = 0.0
			if _timer <= 0.0:
				guard = guard_max
				_telegraph_off()
				weapon_pivot.rotation = Vector3(0, -0.4, 0)
				state = State.CHASE if target != null else State.IDLE
		State.DOWN:
			pass

	move_and_slide()


## Ranged engagement: close past shoot_range, kite back out of
## preferred_min, otherwise hold the band and fire when the cooldown is up.
func _ranged_step(to_target: Vector3, dist: float, delta: float) -> void:
	if dist > shoot_range:
		_face(to_target, delta)
		_move_toward(to_target.normalized() * move_speed, delta)
	elif dist < preferred_min:
		_face(to_target, delta)
		_move_toward(-to_target.normalized() * move_speed * 0.9, delta)
	elif _attack_cd <= 0.0:
		_enter_windup(to_target)
	else:
		_face(to_target, delta)
		velocity.x = lerpf(velocity.x, 0.0, minf(8.0 * delta, 1.0))
		velocity.z = lerpf(velocity.z, 0.0, minf(8.0 * delta, 1.0))


func _nearest_player() -> Node3D:
	var best: Node3D = null
	var best_dist := aggro_range * 4.0
	for node in get_tree().get_nodes_in_group("player"):
		if not (node is Node3D) or node.is_dead:
			continue
		var d: float = global_position.distance_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best = node
	return best


func _enter_windup(to_target: Vector3) -> void:
	state = State.WINDUP
	_timer = windup_time
	telegraph.text = "!"
	telegraph.font_size = _telegraph_size
	telegraph.visible = true
	_face(to_target, 1.0)
	var tw := create_tween()
	tw.tween_property(weapon_pivot, "rotation", Vector3(-1.0, -0.4, 0), windup_time * 0.8) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _cancel_windup() -> void:
	_telegraph_off()
	state = State.IDLE
	weapon_pivot.rotation = Vector3(0, -0.4, 0)


func _telegraph_off() -> void:
	telegraph.visible = false


func _fire(target: Node3D) -> void:
	if projectile_scene == null:
		return
	var bolt := projectile_scene.instantiate()
	var world: Node = get_tree().get_first_node_in_group("world")
	if world == null:
		world = get_tree().current_scene
	world.add_child(bolt)
	var origin := global_position + Vector3(0.0, 1.35, 0.0)
	bolt.global_position = origin
	# Aim at the target's origin: for the player the collision shape sits at
	# local (0,0,0), so the root IS the capsule centre - a fixed height offset
	# would sail over the head.
	var aim := target.global_position - origin
	if aim.length_squared() < 0.0001:
		aim = -global_transform.basis.z
	bolt.call("launch", aim.normalized(), projectile_damage, projectile_poise, get_rid())


func _strike(target: Node3D, dist: float) -> void:
	var tw := create_tween()
	tw.tween_property(weapon_pivot, "rotation", Vector3(0.7, 0.5, 0), 0.12) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if dist <= attack_range + 0.5 and target.has_method("take_damage"):
		target.call("take_damage", attack_damage, poise_damage)


func _walk_home(delta: float) -> void:
	var to_home := home - global_position
	to_home.y = 0.0
	if to_home.length() < 0.6:
		velocity.x = lerpf(velocity.x, 0.0, minf(10.0 * delta, 1.0))
		velocity.z = lerpf(velocity.z, 0.0, minf(10.0 * delta, 1.0))
	else:
		_face(to_home, delta)
		_move_toward(to_home.normalized() * move_speed * 0.8, delta)


func _move_toward(desired: Vector3, delta: float) -> void:
	velocity.x = lerpf(velocity.x, desired.x, minf(8.0 * delta, 1.0))
	velocity.z = lerpf(velocity.z, desired.z, minf(8.0 * delta, 1.0))


func _face(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.001:
		return
	var desired_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, minf(10.0 * delta, 1.0))


func _update_bar() -> void:
	var fraction := clampf(hp / max_hp, 0.0, 1.0)
	bar_fill.scale.x = maxf(fraction, 0.001)
	bar_fill.position.x = -BAR_WIDTH * 0.5 + BAR_WIDTH * fraction * 0.5
	if _bar_material != null:
		_bar_material.albedo_color = Color(0.9, 0.25, 0.2).lerp(Color(0.3, 0.85, 0.35), fraction)


func _flash() -> void:
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3(1.08, 1.08, 1.08), 0.05)
	tween.tween_property(visual, "scale", Vector3.ONE, 0.12)
