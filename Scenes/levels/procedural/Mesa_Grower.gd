extends Node3D

const prefab = preload("res://Scenes/geometry/mesa/mesa.tscn")

const map_size = 50

@export var height_step = 0.5

var extend_mesas_speed = 0.5
var retract_mesas_speed = 2.0

enum Configuration 
{
	inert = 0,
	extending = 1,
	retracting = 2
}
@export var configuration = Configuration.inert

var in_position = false
var mesas = []



func _physics_process(delta):
	
	mesas = get_mesas()
	
	if configuration == Configuration.inert or mesas.size() == 0:
		in_position = true
		return
	
	var in_position_count = 0
	
	for index in range(mesas.size()): #move floor mesas
		var mesa = mesas[index]
		var target = -1
		var step = delta
		
		if configuration == Configuration.extending:
			target = (1+index) * height_step
			step *= extend_mesas_speed * (1+index)
		
		elif configuration == Configuration.retracting:
			step *= retract_mesas_speed
	
		mesa.position.y = move_toward(mesa.position.y, target, step)
			
		if mesa.position.y == target:
			in_position_count += 1
			mesa.preference = mesa.Preference.shallow 
			
	if in_position_count == mesas.size():
		in_position = true


func extend_mesas():
	
	if configuration == Configuration.extending:
		return
	else:
		configuration = Configuration.extending
		in_position = false
		
		
func retract_mesas():
	
	if configuration == Configuration.retracting:
		return
	else:
		configuration = Configuration.retracting
		in_position = false
		
		
func stop_mesas():
	
	if configuration == Configuration.inert:
		return
	else:
		configuration = Configuration.inert
		in_position = true
		
		for mesa in mesas:
			mesa.preference = mesa.Preference.deep 


func spawn_mesas(count):
	
	print("growing ", count, " mesas")
	
	if not is_multiplayer_authority():
		return

	for index in range(count):
		var new_mesa = prefab.instantiate()
		add_child(new_mesa, true)		
		new_mesa.size = randi_range(4, 10) * 0.5
		new_mesa.bottom_drop = 1.0
		new_mesa.preference = new_mesa.Preference.none 
		var boundary = map_size/2.0 - new_mesa.size/2.0
		new_mesa.position.x = randi_range(-boundary, boundary) * 1.0
		new_mesa.position.z = randi_range(-boundary, boundary) * 1.0
		new_mesa.position.y = -1
		new_mesa.rotation.y = randi_range(0, 3) * PI/2
		mesas.append(new_mesa)
		

func clear_mesas():
	
	mesas = get_mesas()
	
	for mesa in mesas:
		mesa.queue_free()
			
	mesas.clear()	
	
	
func get_mesas():
	
	return find_children("*", "AnimatableBody3D", true, false)
