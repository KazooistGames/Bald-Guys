extends Node3D

const floor_mesa_count = 25
const wall_mesa_count = 10

const height_step = 0.25

const mesa_prefab = preload("res://Scenes/objects/mesa/mesa.tscn")

const extend_speed = 1.0
const retract_speed = 1.0

var floor_mesas = []
var wall_mesas = []

enum Configuration 
{
	inert = 0,
	extending = 1,
	retracting = 2
}

var configuration = Configuration.extending


func _ready():
	
	for index in range(floor_mesa_count):
		var new_mesa = mesa_prefab.instantiate()
		$Mesas.add_child(new_mesa)
		
		var size = randi_range(2, 5)
		var boundary = 25.0 - size/2.0
		new_mesa.size = size
		new_mesa.position.x = randi_range(-boundary, boundary)
		new_mesa.position.z = randi_range(-boundary, boundary)
		new_mesa.position.y = 0

		floor_mesas.append(new_mesa)
		
		

func _process(delta):
	
	for index in range(floor_mesas.size()):
		
		var mesa = floor_mesas[index]
		
		if configuration == Configuration.extending:
			var target = (1+index) * 0.5
			var step = extend_speed * delta
			mesa.position.y = move_toward(mesa.position.y, target, step)
		
		elif configuration == Configuration.retracting:
			var target = 0
			var step = retract_speed * delta
			mesa.position.y = move_toward(mesa.position.y, target, step)
			
		
		
func extend():
	
	if configuration == Configuration.extending:
		return
	else:
		configuration = Configuration.extending
		
		
func retract():
	
	if configuration == Configuration.retracting:
		return
	else:
		configuration = Configuration.retracting
		
		
func stop():
	
	if configuration == Configuration.inert:
		return
	else:
		configuration = Configuration.inert

