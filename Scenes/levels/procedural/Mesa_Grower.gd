extends Node3D

const prefab = preload("res://Scenes/objects/mesa/mesa.tscn")

const map_size = 50

@export var height_step = 0.5

var extend_mesas_speed = 0.5
var retract_mesas_speed = 2.0
var reconfigure_period = 60.0
var reconfigure_timer = 0.0

enum MesaConfiguration 
{
	inert = 0,
	extending = 1,
	retracting = 2
}
@export var configuration = MesaConfiguration.inert

var in_position = false


func _physics_process(delta):
	
	var mesas = get_mesas()
	
	if configuration == MesaConfiguration.inert or mesas.size() == 0:
		in_position = true
		return
	
	var in_position_count = 0
	
	for index in range(mesas.size()): #move floor mesas
		var mesa = mesas[index]
		var target = -1
		
		if configuration == MesaConfiguration.extending:
			target = (1+index) * height_step
			var step = extend_mesas_speed * delta * (1+index)
			mesa.position.y = move_toward(mesa.position.y, target, step)
		
		elif configuration == MesaConfiguration.retracting:
			var step = retract_mesas_speed * delta
			mesa.position.y = move_toward(mesa.position.y, target, step)
			
		if mesa.position.y == target:
			in_position_count += 1
			
	if in_position_count == mesas.size():
		in_position = true


func extend_mesas():
	
	if configuration == MesaConfiguration.extending:
		return
	else:
		configuration = MesaConfiguration.extending
		in_position = false
		
		
func retract_mesas():
	
	if configuration == MesaConfiguration.retracting:
		return
	else:
		configuration = MesaConfiguration.retracting
		in_position = false
		
		
func stop_mesas():
	
	if configuration == MesaConfiguration.inert:
		return
	else:
		configuration = MesaConfiguration.inert
		in_position = true


func spawn_mesas(count):
	
	if not is_multiplayer_authority():
		return

	for index in range(count):
		var new_mesa = prefab.instantiate()
		add_child(new_mesa, true)		
		new_mesa.size = randi_range(4, 10) * 0.5
		new_mesa.bottom_drop = 0.25
		new_mesa.preference = new_mesa.Preference.deep 
		var boundary = map_size/2.0 - new_mesa.size/2.0
		new_mesa.position.x = randi_range(-boundary, boundary) * 1.0
		new_mesa.position.z = randi_range(-boundary, boundary) * 1.0
		new_mesa.position.y = -1
		new_mesa.rotation.y = randi_range(0, 3) * PI/2


func clear_mesas():
	
	var mesas = get_mesas()
	
	for mesa in mesas:
		mesa.queue_free()
			
	mesas.clear()	
	
	
func get_mesas():
	
	return find_children("*", "AnimatableBody3D", true, false)
