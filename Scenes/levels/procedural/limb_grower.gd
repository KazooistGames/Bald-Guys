extends Node3D

const prefab = preload("res://Scenes/geometry/pillar/pillar.tscn")

const map_size = 50

const extend_period = 2.0
const retract_period = 2.0

enum Configuration 
{
	inert = 0,
	extending = 1,
	retracting = 2
}
@export var configuration = Configuration.inert

var in_position = false

var limbs = []

signal finished_extending
signal finished_retracting


func _process(delta):
	
	limbs = get_limbs()
	
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


func spawn_limb(orientation, location, radius = 0.25):
	
	var new_limb = prefab.instantiate()
	add_child(new_limb, true)
	new_limb.top_height = 0.5
	new_limb.bottom_drop = 0.5
	new_limb.radius = radius
	new_limb.global_rotation = Vector3(PI/2.0, orientation, 0)
	new_limb.global_position = location
	new_limb.preference = new_limb.Preference.deep
	new_limb.reverse_growth_scale = 0.0
	limbs.append(new_limb)
	
	
func clear_limbs():
		
	for limb in limbs:
		limb.queue_free()
			
	limbs.clear()	

		
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

	
func get_limbs():
	
	return find_children("*", "AnimatableBody3D", true, false)
	
	
