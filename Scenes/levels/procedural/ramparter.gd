extends Node3D

const ramp_prefab = preload("res://Scenes/objects/ramp/ramp.tscn")

const map_size = 50.0

const max_dimension = 15.0

const spacing = 10.0

var ramps = []

enum Configuration 
{
	inert = 0,
	lifting = 1,
	collapsing = 2
}
@export var configuration = Configuration.inert

var in_position = false

var lift_speed = 2.0
var collapse_speed = 2.0


func _physics_process(delta):
	
	ramps = get_ramps()
	
	if configuration == Configuration.inert or ramps.size() == 0:
		in_position = true
		return
	
	var in_position_count = 0
	
	for index in range(ramps.size()): #move floor mesas
		var ramp = ramps[index]
		var target = 0
		var step = delta
		
		if configuration == Configuration.lifting:
			target = (1+index)
			step *= lift_speed 
		
		elif configuration == Configuration.collapsing:
			step *= collapse_speed
			
		ramp.height = move_toward(ramp.height, target, step)
		if ramp.height == target:
			in_position_count += 1
			
	if in_position_count == ramps.size():
		in_position = true 


func spawn_ramps(count):
	
	print("pulling up ", count, " ramps")
	
	if not is_multiplayer_authority():
		return
		
	for index in range(count):
		var new_ramp = ramp_prefab.instantiate()
		add_child(new_ramp, true)		
		
		new_ramp.length = randi_range(1 + index * 2, max_dimension)
		new_ramp.thickness = max(1, abs(max_dimension - new_ramp.length ))
		new_ramp.height = 0.0
		var boundary = map_size/2.0 - max(new_ramp.thickness, new_ramp.length)/2.0
		new_ramp.position.x =  randi_range(-boundary/spacing, boundary/spacing) * spacing
		new_ramp.position.z = randi_range(-boundary/spacing, boundary/spacing) * spacing
		new_ramp.position.y = 0
		new_ramp.rotation.y = randi_range(0, 3) * PI/2
		
		
func clear_mesas():
	
	var ramps = get_ramps()
	
	for ramp in ramps:
		ramp.queue_free()
			
	ramps.clear()	
	

func lift():
	if configuration == Configuration.lifting:
		return
	else:
		configuration = Configuration.lifting
		in_position = false
	
	
func collapse():
	if configuration == Configuration.collapsing:
		return
	else:
		configuration = Configuration.collapsing
		in_position = false
	

func get_ramps():
	
	return find_children("*", "AnimatableBody3D", false, false)
