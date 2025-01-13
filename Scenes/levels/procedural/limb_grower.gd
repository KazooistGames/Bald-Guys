extends Node3D

const prefab = preload("res://Scenes/geometry/pillar/pillar.tscn")

const map_size = 50

var extend_period = 2.0
var retract_period = 0.5

enum Configuration 
{
	inert = 0,
	extending = 1,
	retracting = 2
}
@export var configuration = Configuration.inert

var in_position = false

var limbs = []
var origins = []


func _process(delta):
	
	in_position = true
	
	for index in range(limbs.size()):
		
		var limb = limbs[index]
	
		var target = 0.0
		var step = delta
	
		if configuration == Configuration.inert:
			return
			
		elif configuration == Configuration.extending:
			target = 1.0
			step /= extend_period
			
		elif configuration == Configuration.retracting:
			step /= retract_period

		if limb.reverse_growth_scale != target:
			in_position = false
			limb.reverse_growth_scale = move_toward(limb.reverse_growth_scale, target, step)
			

func spawn_limb(orientation, location):
	
	var new_limb = prefab.instantiate()
	add_child(new_limb, true)
	new_limb.top_height = 0.25
	new_limb.bottom_drop = 0.25
	new_limb.global_rotation = Vector3(PI/2.0, orientation, 0)
	new_limb.global_position = location
	new_limb.preference = new_limb.Preference.deep
	new_limb.reverse_growth_scale = 0.0
	origins.append(location)
	limbs.append(new_limb)
	
	
func clear_limbs():
		
	for limb in limbs:
		limb.queue_free()
			
	limbs.clear()	
	origins.clear()
		
func extend_limbs():
	
	if configuration == Configuration.extending:
		return
	else:
		configuration = Configuration.extending
		in_position = false
		
		
func retract_limbs():
	
	if configuration == Configuration.retracting:
		return
	else:
		configuration = Configuration.retracting
		in_position = false
		
		
func stop_limbs():
	
	if configuration == Configuration.inert:
		return
	else:
		configuration = Configuration.inert
		in_position = true
		
		for limb in limbs:
			limb.preference = limb.Preference.deep 

