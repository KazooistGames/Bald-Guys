extends Node3D


const prefab = preload("res://Scenes/geometry/ramp/ramp.tscn")

const map_size = 50.0

const slope = 0.5

enum Configuration 
{
	inert = 0,
	lifting = 1,
	collapsing = 2
}
@export var configuration = Configuration.inert

@onready var multiplayer_spawner = $MultiplayerSpawner

var ramps = []
var heights = []

var lift_speed = 3.0
var collapse_speed = 3.0

var in_position = false

signal finished_lifting
signal finished_collapsing


func _ready():
	
	multiplayer_spawner.spawn_function = spawn_ramp
	

func _physics_process(delta):
	
	ramps = get_ramps()
	
	in_position = true
	
	if configuration == Configuration.inert or ramps.size() == 0:
		return

	for index in range(ramps.size()): #move floor mesas
		var ramp = ramps[index]
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


func create_ramp(coordinates, length = 1.0, thickness = 2.0, height = 0.5, verify_position = false, y_rotation = 0):
	
	var data = {}
	
	if verify_position:			
		coordinates.y = height_at_coordinates(coordinates) + 0.5
	
	var dimensions = Vector3.ZERO
	dimensions.x = length
	dimensions.z = thickness
	dimensions.y = 0.0
	
	data["dimensions"] = dimensions
	data["position"] = coordinates
	data["rotation"] = Vector3.ZERO
	data["rotation"].y = y_rotation
	data["height"] = height
	
	multiplayer_spawner.spawn(data)


func spawn_ramp(data : Dictionary):
	
	var new_ramp = prefab.instantiate()
	
	for key in data.keys():
		new_ramp.set(key, data[key])

	ramps.append(new_ramp)
	heights.append(data["height"])
	
	return new_ramp
	
		
func height_at_coordinates(coordinates):
	
	var origin = Vector3(coordinates.x, map_size, coordinates.z)
	var destination = Vector3(coordinates.x, -map_size - 1, coordinates.z)
	var query = PhysicsRayQueryParameters3D.create(origin, destination, 0b0001, [])
	query.hit_back_faces = false
	query.hit_from_inside = false
	var collision = get_world_3d().direct_space_state.intersect_ray(query)
	return collision["position"].y
	
		
func clear_ramps():
	
	ramps = get_ramps()
	
	for ramp in ramps:
		ramp.queue_free()
			
	ramps.clear()	
	heights.clear()
	
	
func stop():
	
	if configuration == Configuration.inert:
		return
	else:
		configuration = Configuration.inert
		

func lift():
	
	if configuration == Configuration.lifting:
		return
	else:
		configuration = Configuration.lifting
	
	
func collapse():
	
	if configuration == Configuration.collapsing:
		return
	else:
		configuration = Configuration.collapsing
	

func get_ramps():
	
	return find_children("*", "AnimatableBody3D", false, false)

