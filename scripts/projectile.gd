extends Node3D
## Bolt: flies in a straight line and raycasts every step, so arena cover
## blocks it. Foe bolts (harrier) damage the player; player bolts (ranger)
## damage attackable foes instead. Pops on any geometry.

const LIFETIME := 3.0
const SPEED := 20.0

var direction := Vector3.FORWARD
var damage := 12.0
var poise_damage := 16.0
## True when fired by the player: hits foes, never the player.
var friendly := false
var _life := LIFETIME
var _exclude: Array[RID] = []


## Called by the shooter right after the bolt enters the tree.
func launch(dir: Vector3, dmg: float, poise: float, shooter: RID = RID(),
		is_player_shot := false) -> void:
	direction = dir.normalized()
	damage = dmg
	poise_damage = poise
	friendly = is_player_shot
	if shooter.is_valid():
		_exclude = [shooter]
	_life = LIFETIME
	if absf(direction.y) < 0.999:
		look_at(global_position + direction)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		_pop()
		return
	var from := global_position
	var to := from + direction * SPEED * delta
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = _exclude
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit["collider"]
		if collider is Node and friendly \
				and (collider as Node).is_in_group("attackable") \
				and collider.has_method("take_damage"):
			# Foes take (amount, from_pos) like every other attacker reports.
			collider.call("take_damage", damage, global_position)
		elif collider is Node and (collider as Node).is_in_group("player") \
				and collider.has_method("take_damage"):
			collider.call("take_damage", damage, poise_damage)
		_pop()
		return
	global_position = to


func _pop() -> void:
	set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.08)
	tween.tween_callback(queue_free)
