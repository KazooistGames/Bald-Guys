extends Node3D


const ramp_prefab = preload("res://Scenes/geometry/ramp/ramp.tscn")

const map_size = 50.0

const slope = 0.5

enum Configuration 
{
	inert = 0,
	lifting = 1,
	collapsing = 2
}
@export var configuration = Configuration.inert

var ramps = []
@export var heights = []

var lift_speed = 3.0
var collapse_speed = 3.0

var in_position = false

signal finished_lifting
signal finished_collapsing


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
		
		if ramp.height != target:
			in_position = false
			ramp.height = move_toward(ramp.height, target, step)
			
	if not in_position:
		pass
		
	elif configuration == Configuration.lifting:
		finished_lifting.emit()
		
	elif configuration == Configuration.collapsing:
		
		finished_collapsing.emit()


func spawn_ramp(coordinates, length = 1.0, thickness = 2.0, height = 0.5, verify_position = false, y_rotation = 0):
	
	var new_ramp = ramp_prefab.instantiate()
	add_child(new_ramp, true)		
	new_ramp.length = length
	new_ramp.thickness = thickness
	new_ramp.height = 0.0
	new_ramp.position = coordinates
	new_ramp.rotation.y = y_rotation
	
	if verify_position:			
		new_ramp.position.y = height_at_coordinates(coordinates) + 0.5
		
	heights.append(height)
	#print("pulling up ramp at ", new_ramp.position)
		
		
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

