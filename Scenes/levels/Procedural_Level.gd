extends Node3D


const map_size = 50


const mesa_prefab = preload("res://Scenes/objects/mesa/mesa.tscn")

var height_step = 0.5
var extend_mesas_speed = 0.5
var retract_mesas_speed = 2.0
var reconfigure_period = 60.0
var reconfigure_timer = 0.0

var floor_mesa_count = 25
var floor_mesas = []

var hover_mesa_count = 5
var hover_mesas = []
var hover_vectors = []

enum MesaConfiguration 
{
	inert = 0,
	extending = 1,
	retracting = 2
}

var mesa_config = MesaConfiguration.inert
		
		
func _ready():

	for index in range(hover_mesa_count):
		var new_mesa = mesa_prefab.instantiate()
		$Mesas.add_child(new_mesa)		
		var mesa_size = randi_range(3, 5)
		var boundary = map_size/2.0 - mesa_size/2.0
		new_mesa.size = mesa_size
		new_mesa.position.x = randi_range(-boundary, boundary)
		new_mesa.position.z = randi_range(-boundary, boundary)
		new_mesa.position.y = -1
		new_mesa.bottom_drop = height_step
		new_mesa.preference = new_mesa.Preference.shallow
		hover_mesas.append(new_mesa)
		var new_vector = Vector3(randf(), randf(), randf()).normalized()
		hover_vectors.append(new_vector)


func _physics_process(delta):
	
	reposition_hover_mesas(delta)	
	
	if reconfigure_timer >= reconfigure_period:
		reconfigure_timer -= reconfigure_period
		retract_mesas()
		
	elif mesa_config == MesaConfiguration.inert:
		reconfigure_timer += delta				
		
	else:
		reposition_floor_mesas(delta)
	
		
func reconfigure_mesas():
	
	hover_vectors.clear()
	for i in range(hover_mesa_count):	
		var new_vector = Vector3(randf(), randf(), randf()).normalized()
		hover_vectors.append(new_vector)
	
	for mesa in floor_mesas:
		mesa.queue_free()
		
	floor_mesas.clear()

	for index in range(floor_mesa_count):
		var new_mesa = mesa_prefab.instantiate()
		$Mesas.add_child(new_mesa)		
		var mesa_size = randi_range(2, 5)
		var boundary = map_size/2.0 - mesa_size/2.0
		new_mesa.size = mesa_size
		new_mesa.position.x = randi_range(-boundary, boundary)
		new_mesa.position.z = randi_range(-boundary, boundary)
		new_mesa.position.y = -1
		new_mesa.bottom_drop = height_step
		new_mesa.preference = new_mesa.Preference.deep

		floor_mesas.append(new_mesa)
		
	extend_mesas()
	
	
func reposition_floor_mesas(delta):
	
	var mesas_in_position = 0
	
	for index in range(floor_mesas.size()): #move floor mesas
		var mesa = floor_mesas[index]
		var target = -1
		
		if mesa_config == MesaConfiguration.extending:
			target = (1+index) * height_step
			var step = extend_mesas_speed * delta * (1+index)
			mesa.position.y = move_toward(mesa.position.y, target, step)
		
		elif mesa_config == MesaConfiguration.retracting:
			var step = retract_mesas_speed * delta
			mesa.position.y = move_toward(mesa.position.y, target, step)
			
		if mesa.position.y == target:
			mesas_in_position += 1
		
	if mesas_in_position != floor_mesas.size():
		pass	
	elif mesa_config == MesaConfiguration.extending:
		stop_mesas()	
	elif mesa_config == MesaConfiguration.retracting:
		reconfigure_mesas()
	
	
func reposition_hover_mesas(delta):
	
	for index in range(hover_mesas.size()): #move hover mesas	
		var mesa = hover_mesas[index]
		var height = (index + 1) * height_step * 5.0
		var boundary = map_size/2.0 - mesa.size/2.0
		var trajectory = hover_vectors[index]
		
		if mesa.position.y > height:
			trajectory.y = -trajectory.y
			mesa.position.y = height
			
		elif mesa.position.y < 0:
			trajectory.y = -trajectory.y
			mesa.position.y = 0
			
		elif abs(mesa.position.x) > boundary:
			trajectory.x = -trajectory.x
			var offset = abs(mesa.position.x) - boundary
			mesa.position.x -= sign(mesa.position.x) * offset
			
		elif abs(mesa.position.z) > boundary:
			trajectory.z = -trajectory.z
			var offset = abs(mesa.position.z) - boundary
			mesa.position.x -= sign(mesa.position.z) * offset

		var step = extend_mesas_speed * delta * (index * 2.0 + 1) 
		mesa.position += trajectory * step	
		hover_vectors[index] = trajectory
	
		
func extend_mesas():
	
	if mesa_config == MesaConfiguration.extending:
		return
	else:
		mesa_config = MesaConfiguration.extending
		
		
func retract_mesas():
	
	if mesa_config == MesaConfiguration.retracting:
		return
	else:
		mesa_config = MesaConfiguration.retracting
		
		
func stop_mesas():
	
	if mesa_config == MesaConfiguration.inert:
		return
	else:
		mesa_config = MesaConfiguration.inert

