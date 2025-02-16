extends Node3D

const prefab = preload("res://Scenes/geometry/mesa/mesa.tscn")

const map_size = 50
const gap = 2.0

enum Configuration 
{
	inert = 0,
	extending = 1,
	retracting = 2
}
@export var configuration = Configuration.inert

@export var height_step = 0.5

@onready var multiplayer_spawner = $MultiplayerSpawner

var extend_speed = 0.5
var retract_speed = 2.0

var in_position = false
var mesas = []

signal finished_extending
signal finished_retracting


func _ready():
	
	multiplayer_spawner.spawn_function = spawn_mesa
	

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


func create_mesas(count):
	
	if not is_multiplayer_authority():
		return

	for index in range(count):
		
		var data = {}	
		var random_size = randi_range(4, 10) * 0.5	
		var boundary = map_size/2.0 - random_size/2.0
		boundary /= gap
		var random_pos = Vector3.ZERO
		random_pos.x = randi_range(-boundary, boundary) * gap
		random_pos.y = -1
		random_pos.z = randi_range(-boundary, boundary) * gap
		data["position"] = random_pos	
		data["rotation"] = Vector3(0, randi_range(0, 3) * PI/2, 0)
		data["size"] = random_size
		data["top_height"] = 0
		data["bottom_drop"] = 1		
		multiplayer_spawner.spawn(data)
		

func spawn_mesa(data : Dictionary):
	
	var new_mesa = prefab.instantiate()
	new_mesa.preference = new_mesa.Preference.none 
	
	for key in data.keys():
		new_mesa.set(key, data[key])

	mesas.append(new_mesa)
	
	return new_mesa


func clear_mesas():
	
	mesas = get_mesas()
	
	for mesa in mesas:
		mesa.queue_free()
			
	mesas.clear()	
	
	
func get_mesas():
	
	return find_children("*", "AnimatableBody3D", true, false)
	
	
	
