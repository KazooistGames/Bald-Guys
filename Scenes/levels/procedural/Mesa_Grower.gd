extends Node3D

const prefab = preload("res://Scenes/geometry/mesa/mesa.tscn")
const gap = 3.0

@export var Map_Size : int = 50

enum Configuration 
{
	inert = 0,
	extending = 1,
	retracting = 2
}
@export var configuration = Configuration.inert
@export var height_step = 0.75

@onready var rng = RandomNumberGenerator.new()
@onready var previous_rng_state = rng.state
@onready var unlagger = $LagCompensator

var extend_speed = 0.75
var retract_speed = 3.0
var in_position = false
var mesas = []
var count = 30

signal finished_extending
signal finished_retracting


func _physics_process(delta):
	
	delta *= unlagger.delta_scalar(delta)	
	in_position = true
	
	if configuration == Configuration.inert or mesas.size() == 0:
		return
	
	for index in range(mesas.size()): #move floor mesas
		var mesa = mesas[index]
		var target = -1
		var step = delta
		
		if configuration == Configuration.extending:
			target = (1+index) * height_step
			step *= extend_speed * (1+index)
		
		elif configuration == Configuration.retracting:
			step *= retract_speed
	
		mesa.position.y = move_toward(mesa.position.y, target, step)
		
		if mesa.position.y != target:
			in_position = false
	
	if not in_position:
		pass
		
	elif configuration == Configuration.extending:
		finished_extending.emit()
		
	elif configuration == Configuration.retracting:
		finished_retracting.emit()


@rpc("call_local", "reliable")
func extend_mesas():
		
	if configuration != Configuration.extending:
		print('mesas extending')
		configuration = Configuration.extending
		unlagger.reset()
		
		if mesas.size() == 0:
			finished_extending.emit()	
			
	else:
		finished_extending.emit()
		
		
@rpc("call_local", "reliable")
func retract_mesas():
	
	if configuration != Configuration.retracting:
		print('mesas retracting')
		configuration = Configuration.retracting
		unlagger.reset()
		
		if mesas.size() == 0:
			finished_retracting.emit()	
		
	else:
		finished_retracting.emit()
	
	
@rpc("call_local", "reliable")		
func stop():

	if configuration != Configuration.inert:
		configuration = Configuration.inert
		
		for mesa in mesas:
			mesa.preference = mesa.Preference.locked 


@rpc("call_local", "reliable")
func create_mesas(hidden : bool = true):
	
	previous_rng_state = rng.state
	#print(multiplayer.get_unique_id(), " ", name, " seed is ", rng.seed, " state is ", rng.state)
	for index in range(count):
		var tier = index/10
		var min_size = 12 - tier * 3
		var max_size = 18 - tier * 3
		var random_size = rng.randi_range(min_size, max_size) * 0.5	
		var boundary = Map_Size/2.0 - random_size/2.0
		boundary /= gap

		var new_mesa = prefab.instantiate()
		add_child(new_mesa)
		new_mesa.position.x = rng.randi_range(-boundary, boundary) * gap
		new_mesa.position.y = -1.0 if hidden else (1+index) * height_step
		new_mesa.position.z = rng.randi_range(-boundary, boundary) * gap
		new_mesa.rotation.y = rng.randi_range(0, 3) * PI/2
		new_mesa.preference = new_mesa.Preference.none if hidden else new_mesa.Preference.deep
		new_mesa.size = random_size
		mesas.append(new_mesa)


@rpc("call_local", "reliable")
func clear_mesas():
	
	mesas = get_mesas()
	
	for mesa in mesas:
		mesa.queue_free()
			
	mesas.clear()	
	
	
func get_mesas():
	
	return find_children("*", "AnimatableBody3D", true, false)
	
	
@rpc("call_local", "authority", "reliable")	
func rpc_set_rng(new_seed, new_state):
	
	if new_seed != null:
		rng.seed = new_seed
		
	if new_state != null:
		rng.state = new_state
		
	print(multiplayer.get_unique_id(), " ", name, " seed is ", rng.seed, " state is ", rng.state)
