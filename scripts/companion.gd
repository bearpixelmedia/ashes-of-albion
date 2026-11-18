extends CharacterBody3D
## Maelis Orr, the recruitable cleric: she waits in the town square until the
## champion presses E beside her, then follows at a respectful distance and
## mends the party on a cooldown. Foes can strike her like the player — at zero
## health she goes down for a while (and can be picked back up with E), which
## the HUD's party frame and her ALLY nameplate report.

signal joined
signal went_down
signal revived

@export var party_name := "Maelis Orr"
@export var party_role := "Cleric"
@export var max_hp := 80.0
@export var heal_amount := 18.0
@export var heal_cooldown := 8.0
@export var heal_range := 9.0
## She only spends the heal once the champion is below this fraction of health.
@export var heal_threshold := 0.75
@export var follow_distance := 2.4
@export var move_speed := 4.2
@export var downed_time := 8.0
@export var recruit_range := 4.0

var hp := 80.0
var recruited := false
var is_downed := false
var heal_cd := 0.0
var downed_timer := 0.0

@onready var visual: Node3D = $Visual
@onready var prompt: Label3D = $Prompt
@onready var nameplate: Label3D = $Nameplate

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	add_to_group("companions")
	hp = max_hp
	prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode != KEY_E and key.physical_keycode != KEY_E:
		return
	var target := _player()
	if target == null or global_position.distance_to(target.global_position) > recruit_range:
		return
	if not recruited:
		recruit()
	elif is_downed:
		revive()
	else:
		return
	get_viewport().set_input_as_handled()


## Join the party (or get back up). A freshly recruited cleric arrives at full
## health; a revived one returns at half.
func recruit() -> void:
	if recruited and not is_downed:
		return
	recruited = true
	is_downed = false
	downed_timer = 0.0
	hp = max_hp
	heal_cd = maxf(heal_cd, 0.5)
	joined.emit()


## Foes strike her through the same call they use on the player; poise is
## accepted and ignored so that shared path needs no special case.
func take_damage(amount: float, _poise: float = 0.0) -> void:
	if not recruited or is_downed:
		return
	hp = maxf(hp - maxf(amount, 0.0), 0.0)
	if hp <= 0.0:
		_go_down()


func _go_down() -> void:
	is_downed = true
	downed_timer = downed_time
	heal_cd = 0.0
	went_down.emit()


func revive() -> void:
	if not is_downed:
		return
	is_downed = false
	downed_timer = 0.0
	hp = maxf(hp, max_hp * 0.5)
	revived.emit()


func _physics_process(delta: float) -> void:
	if is_downed:
		downed_timer -= delta
		if downed_timer <= 0.0:
			revive()
		velocity = Vector3.ZERO
		visual.rotation = Vector3(-PI * 0.45, 0.0, 0.0)
		move_and_slide()
		return
	visual.rotation = Vector3.ZERO
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	heal_cd = maxf(heal_cd - delta, 0.0)

	var target := _player()
	if target == null:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var dist := to_target.length()
	prompt.visible = not recruited and dist <= recruit_range
	if not recruited:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	_try_heal(target, dist)
	if dist > follow_distance:
		var dir := to_target.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		_face(dir, delta)
	else:
		velocity.x = lerpf(velocity.x, 0.0, minf(10.0 * delta, 1.0))
		velocity.z = lerpf(velocity.z, 0.0, minf(10.0 * delta, 1.0))
	move_and_slide()


func _try_heal(target, dist: float) -> void:
	if heal_cd > 0.0 or dist > heal_range:
		return
	if target.is_dead or target.hp >= target.max_hp:
		return
	if target.hp > target.max_hp * heal_threshold:
		return
	var healed := minf(heal_amount, target.max_hp - target.hp)
	if healed <= 0.0:
		return
	target.hp += healed
	heal_cd = heal_cooldown


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _face(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.001:
		return
	var desired_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, minf(10.0 * delta, 1.0))
