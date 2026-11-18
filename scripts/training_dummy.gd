extends StaticBody3D
## Training dummy: takes damage, shows a billboarded health bar,
## topples when defeated, and resets when the player re-enters the loop.

signal defeated
signal health_changed(hp: float, max_hp: float)

const BAR_WIDTH := 1.4

@export var max_hp := 100.0
## The dummy is a sparring target, not a combatant: neutral grey flag.
@export var combat_flag: String = "neutral"

@onready var visual: Node3D = $Visual
@onready var body_mesh: MeshInstance3D = $Visual/Body
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var health_bar: Node3D = $HealthBar
@onready var bar_fill: MeshInstance3D = $HealthBar/BarFill

var hp := 100.0
var is_defeated := false
var combat_name := ""
var flag_chip: Node3D = null
var _bar_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("attackable")
	var plate := get_node_or_null("HealthBar/NameLabel") as Label3D
	combat_name = plate.text if plate != null else name
	flag_chip = CombatFlags.attach_chip(self, combat_flag, 3.0)
	_bar_material = bar_fill.get_surface_override_material(0).duplicate() as StandardMaterial3D
	bar_fill.set_surface_override_material(0, _bar_material)
	reset()


## from_pos matches the foe API so any attacker can report where it struck
## from; the dummy has no shield, so it is unused here.
func take_damage(amount: float, from_pos: Vector3 = Vector3.INF) -> void:
	if is_defeated:
		return
	hp = maxf(hp - amount, 0.0)
	_update_bar()
	_flash()
	health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		is_defeated = true
		_defeat()
		defeated.emit()


func reset() -> void:
	hp = max_hp
	is_defeated = false
	rotation = Vector3.ZERO
	scale = Vector3.ONE
	collision_shape.set_deferred("disabled", false)
	health_bar.visible = true
	flag_chip.visible = true
	_update_bar()
	health_changed.emit(hp, max_hp)


func _defeat() -> void:
	collision_shape.set_deferred("disabled", true)
	health_bar.visible = false
	flag_chip.visible = false
	var tween := create_tween()
	tween.tween_property(self, "rotation", Vector3(-PI * 0.45, rotation.y, 0), 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


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
