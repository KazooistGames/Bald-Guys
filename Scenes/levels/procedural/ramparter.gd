extends Node3D


const ramp_prefab = preload("res://Scenes/geometry/ramp/ramp.tscn")

const map_size = 50.0

const max_dimension = 15.0

const spacing = 10.0

enum Configuration 
{
	inert = 0,
	lifting = 1,
	collapsing = 2
}
@export var configuration = Configuration.inert

var ramps = []

var lift_speed = 2.0
var collapse_speed = 2.0

func _physics_process(delta):
	
	ramps = get_ramps()
	
	for index in range(ramps.size()): #move floor mesas
		var ramp = ramps[index]
		var target = 0
		var step = delta
		
		if configuration == Configuration.lifting:
			target = 1.0
			step *= lift_speed 
		
		elif configuration == Configuration.collapsing:
			step *= collapse_speed
			
		var height_change = clamp(target - ramp.height, -step, step)
		ramp.height = move_toward(ramp.height, target, step)
		ramp.position.y += height_change/2.0

func spawn_ramp(coordinates, length = 1.0, thickness = 2.0, verify_position = false):
	
	var new_ramp = ramp_prefab.instantiate()
	add_child(new_ramp, true)		
	new_ramp.length = length
	new_ramp.thickness = thickness
	new_ramp.height = 0.0
	new_ramp.position = coordinates
	new_ramp.rotation.y = randi_range(0, 3) * PI/2
	
	if verify_position:			
		new_ramp.position.y = height_at_coordinates(coordinates) + 0.5
		
	print("pulling up ramp at ", new_ramp.position)
		
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
