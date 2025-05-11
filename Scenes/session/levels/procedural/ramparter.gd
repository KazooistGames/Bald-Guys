extends Node3D

const prefab = preload("res://Scenes/geometry/ramp/ramp.tscn")

const slope = 0.5

enum Configuration 
{
	inert = 0,
	lifting = 1,
	collapsing = 2
}

@export var Map_Size = 50
@export var configuration = Configuration.inert

@onready var rng = RandomNumberGenerator.new()
@onready var previous_rng_state = rng.state
@onready var unlagger = $LagCompensator

var ramps = []
var heights = []

var lift_speed = 3.0
var collapse_speed = 5.0

var in_position = false

var ramp_floor_freq = 0.5
var ramp_roof_freq = 0.5

signal finished_lifting
signal finished_collapsing


func _physics_process(delta):
	
	delta *= unlagger.delta_scalar(delta)
	in_position = true
	
	if configuration == Configuration.inert or ramps.size() == 0:
		return

	for index in range(ramps.size()): #move floor mesas
		var ramp = ramps[index]
		
		if ramp == null:
			return
			
		var target = 0
		var step = delta	
		
		if heights.size() <= 0:
			pass
			
		elif configuration == Configuration.lifting:
			target = heights[index]
			step *= lift_speed 
		
		elif configuration == Configuration.collapsing:
			step *= collapse_speed
		
		if ramp.dimensions.y != target:
			in_position = false
			ramp.dimensions.y = move_toward(ramp.dimensions.y, target, step)	
			
	if not in_position:
		pass
			
	elif configuration == Configuration.lifting:
		finished_lifting.emit()	
			
	elif configuration == Configuration.collapsing:	
		finished_collapsing.emit()


@rpc("call_local", "reliable")	
func create_ramps(hidden : bool = true):
	
	previous_rng_state = rng.state
	
	for mesa in $"../Mesa_Grower".mesas:
			
		if rng.randf() <= ramp_roof_freq: #roof
			var y_offset = Vector3.DOWN * rng.randi_range(0, 1) * 0.75
			var rand_rotation = PI/2.0 * float(rng.randi_range(0, 3))
			spawn_ramp(mesa.position + y_offset, mesa.size, mesa.size, mesa.size/2.0, false,  rand_rotation, hidden)
			
		if rng.randf() <= ramp_floor_freq: #floor
			var y_rotation = rng.randi_range(0, 3) * PI/2
			var base_offset = Vector3(-cos(y_rotation), 0, sin(y_rotation)).normalized() * mesa.size
			var ramp_position = mesa.position + base_offset
			ramp_position.y = 0
			var ramp_height
			
			if mesa.position.y >= mesa.size * 2.0:
				ramp_height = mesa.size * 2.0
			elif mesa.position.y >= mesa.size:
				ramp_height = mesa.size
			else:		
				ramp_height = minf(mesa.position.y, mesa.size / 2.0)
				
			spawn_ramp(ramp_position, mesa.size, mesa.size, ramp_height, false, y_rotation, hidden)
	

@rpc("call_local", "reliable")	
func spawn_ramp(coordinates, length = 1.0, thickness = 2.0, height = 0.5, verify_position = false, y_rotation = 0, hidden : bool = true):
	
	if verify_position:			
		coordinates.y = height_at_coordinates(coordinates) + 0.5
	
	var new_ramp = prefab.instantiate()
	var dimensions = Vector3.ZERO
	dimensions.x = length
	dimensions.z = thickness
	dimensions.y = 0.0 if hidden else height
	new_ramp.dimensions = dimensions
	new_ramp.position = coordinates
	new_ramp.rotation = Vector3.ZERO
	new_ramp.rotation.y = y_rotation
	add_child(new_ramp)
	ramps.append(new_ramp)
	heights.append(height)
	
		
func height_at_coordinates(coordinates):
	
	var origin = Vector3(coordinates.x, Map_Size, coordinates.z)
	var destination = Vector3(coordinates.x, -Map_Size - 1, coordinates.z)
	var query = PhysicsRayQueryParameters3D.create(origin, destination, 0b0001, [])
	query.hit_back_faces = false
	query.hit_from_inside = false
	var collision = get_world_3d().direct_space_state.intersect_ray(query)
	return collision["position"].y
	
	
@rpc("call_local", "reliable")	
func clear_ramps():
	
	ramps = get_ramps()
	
	for ramp in ramps:
		ramp.queue_free()
			
	ramps.clear()	
	heights.clear()
	
	
@rpc("call_local", "reliable")	
func stop():
	
	if configuration == Configuration.inert:
		return
	else:
		configuration = Configuration.inert
		
		
@rpc("call_local", "reliable")	
func lift():
	
	unlagger.reset()
	
	if configuration == Configuration.lifting:
		finished_lifting.emit()
	
	else:
		configuration = Configuration.lifting
		
		if ramps.size() == 0:
			finished_lifting.emit()
	
	
@rpc("call_local", "reliable")	
func collapse():
	
	unlagger.reset()
	
	if configuration == Configuration.collapsing:
		finished_collapsing.emit()
		
	else:
		configuration = Configuration.collapsing
		
		if ramps.size() == 0:
			finished_collapsing.emit()
			

func get_ramps():
	
	return find_children("*", "AnimatableBody3D", false, false)


@rpc("call_local", "authority", "reliable")	
func rpc_set_rng(new_seed, new_state):
	
	if new_seed != null:
		rng.seed = new_seed
		
	if new_state != null:
		rng.state = new_state

	print(multiplayer.get_unique_id(), " ", name, " seed is ", rng.seed, " state is ", rng.state)
