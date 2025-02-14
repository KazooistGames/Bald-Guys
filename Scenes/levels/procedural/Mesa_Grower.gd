extends Node3D

const prefab = preload("res://Scenes/geometry/mesa/mesa.tscn")

const map_size = 50
const gap = 2.0

@export var height_step = 0.5

var extend_speed = 0.5
var retract_speed = 2.0

enum Configuration 
{
	inert = 0,
	extending = 1,
	retracting = 2
}
@export var configuration = Configuration.inert

var in_position = false
var mesas = []

signal finished_extending
signal finished_retracting


func _physics_process(delta):
	
	mesas = get_mesas()
	
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



func extend_mesas():
	
	if configuration == Configuration.extending:
		return
	else:
		configuration = Configuration.extending

		
		
func retract_mesas():
	
	if configuration == Configuration.retracting:
		return
	else:
		configuration = Configuration.retracting
	
		
		
func stop_mesas():
	
	mesas = get_mesas()
	
	if configuration == Configuration.inert:
		return
	else:
		configuration = Configuration.inert
		
		for mesa in mesas:
			mesa.preference = mesa.Preference.locked 
			mesa.altered.emit()


func spawn_mesas(count):
	
	if not is_multiplayer_authority():
		return

	for index in range(count):
		var new_mesa = prefab.instantiate()
		new_mesa.size = randi_range(4, 10) * 0.5
		new_mesa.top_height = 0.0
		new_mesa.bottom_drop = 1.0
		new_mesa.preference = new_mesa.Preference.none 
		add_child(new_mesa, true)	
		var boundary = map_size/2.0 - new_mesa.size/2.0
		boundary /= gap
		new_mesa.position.x = randi_range(-boundary, boundary) * gap
		new_mesa.position.z = randi_range(-boundary, boundary) * gap
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
