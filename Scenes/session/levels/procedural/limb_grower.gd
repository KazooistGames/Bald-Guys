extends Node3D

const prefab = preload("res://Scenes/geometry/pillar/pillar.tscn")

@export var Map_Size = 50

const extend_period = 2.0
const retract_period = 2.0

enum Configuration 
{
	inert = 0,
	extending = 1,
	retracting = 2
}
@export var configuration = Configuration.inert
@onready var rng = RandomNumberGenerator.new()
@onready var previous_rng_state = rng.state
@onready var unlagger = $LagCompensator

var in_position = false

var limbs = []

signal finished_extending
signal finished_retracting


var limb_freq = 1.0/3.0


func _physics_process(delta):
	
	delta *= unlagger.delta_scalar(delta)
	
	in_position = true
	
	if configuration == Configuration.inert or limbs.size() == 0:
		return
	
	for index in range(limbs.size()):
		
		var limb = limbs[index]
	
		var target = 0.0
		var step = delta
			
		if configuration == Configuration.extending:
			target = 1.0
			step /= extend_period
			
		elif configuration == Configuration.retracting:
			step /= retract_period

		if limb.reverse_growth_scale != target:
			in_position = false
			limb.reverse_growth_scale = move_toward(limb.reverse_growth_scale, target, step)
			
	if not in_position:
		pass
		
	elif configuration == Configuration.extending:
		finished_extending.emit()
		
	elif configuration == Configuration.retracting:
		finished_retracting.emit()


@rpc("call_local", "reliable")
func create_limbs(hidden : bool = true):
	
	previous_rng_state = rng.state
	var orientation_to_use = 0
	
	for mesa in $"../Mesa_Grower".mesas:
		
		var limbs_on_mesa = 0

		while rng.randf() <= limb_freq and limbs_on_mesa < 4:
			var limb_position = mesa.global_position - Vector3.UP * 0.375
			spawn_limb(orientation_to_use, limb_position, 1.0/3.0, hidden)
			orientation_to_use += PI / 2.0
			orientation_to_use = fmod(orientation_to_use, 2.0 * PI)


@rpc("call_local", "reliable")
func spawn_limb(orientation, location, radius = 1.0/2.0, hidden : bool = true):
	
	var new_limb = prefab.instantiate()
	new_limb.preference = new_limb.Preference.deep
	new_limb.top_height = 0.5
	new_limb.bottom_drop = 0.5
	new_limb.radius = radius
	new_limb.rotation = Vector3(PI/2.0, orientation, 0)
	new_limb.position = location
	new_limb.reverse_growth_scale = 0.0 if hidden else 1.0
	new_limb.preference = new_limb.Preference.deep
	add_child(new_limb)
	limbs.append(new_limb)
	
	
@rpc("call_local", "reliable")
func clear_limbs():
		
	for limb in limbs:
		limb.queue_free()
			
	limbs.clear()	


@rpc("call_local", "reliable")		
func extend_limbs():
	
	if configuration != Configuration.extending:
		unlagger.reset()
		configuration = Configuration.extending
		in_position = false
		
		if limbs.size() == 0:
			finished_extending.emit()	
			
	else:
		finished_extending.emit()
		
		
@rpc("call_local", "reliable")	
func retract_limbs():
	
	if configuration != Configuration.retracting:
		configuration = Configuration.retracting
		in_position = false
		unlagger.reset()
		
		for limb in limbs:
			limb.preference = limb.Preference.deep 
			
		if limbs.size() == 0:
			finished_retracting.emit()	
			
	else:
		finished_retracting.emit()
		
		
@rpc("call_local", "reliable")
func stop():
	
	if configuration != Configuration.inert:
		configuration = Configuration.inert
		in_position = true
		
		for limb in limbs:
			limb.preference = limb.Preference.locked 

	
func get_limbs():
	
	return find_children("*", "AnimatableBody3D", true, false)
	
	
@rpc("call_local", "authority", "reliable")	
func rpc_set_rng(new_seed, new_state):
	
	if new_seed != null:
		rng.seed = new_seed
		
	if new_state != null:
		rng.state = new_state

	print(multiplayer.get_unique_id(), " ", name, " seed is ", rng.seed, " state is ", rng.state)
