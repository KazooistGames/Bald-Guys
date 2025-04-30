extends Node3D

const prefab = preload("res://Scenes/geometry/mesa/mesa.tscn")

const gap = 2.0

@export var map_size : int = 50

enum Configuration 
{
	inert = 0,
	extending = 1,
	retracting = 2
}
@export var configuration = Configuration.inert

@export var height_step = 0.5

@onready var rng = RandomNumberGenerator.new()

@onready var unlagger = $LagCompensator

var extend_speed = 0.5
var retract_speed = 2.0

var in_position = false
var mesas = []

var count = 30

signal finished_extending
signal finished_retracting

func _physics_process(delta):
	
	delta *= unlagger.delta_scalar(delta)
	
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


@rpc("call_local", "reliable")
func extend_mesas():
	
	unlagger.reset()
	
	if configuration != Configuration.extending:
		configuration = Configuration.extending
		
		if mesas.size() == 0:
			finished_extending.emit()	
			
	else:
		finished_extending.emit()
		
		
@rpc("call_local", "reliable")
func retract_mesas():
	
	unlagger.reset()
	
	if configuration != Configuration.retracting:
		configuration = Configuration.retracting
		
		if mesas.size() == 0:
			finished_retracting.emit()	
		
	else:
		finished_retracting.emit()
	
	
@rpc("call_local", "reliable")		
func stop():

	if configuration != Configuration.inert:
		configuration = Configuration.inert
		
		for mesa in mesas:
			mesa.preference = mesa.Preference.locked 


@rpc("call_local", "reliable")
func create_mesas(new_seed, hidden : bool = true):
	
	rng.seed = new_seed
	
	for index in range(count):
			
		var random_size = rng.randi_range(4, 10) * 0.5	
		var boundary = map_size/2.0 - random_size/2.0
		boundary /= gap

		var new_mesa = prefab.instantiate()
		add_child(new_mesa)
		new_mesa.position.x = rng.randi_range(-boundary, boundary) * gap
		new_mesa.position.y = -1 if hidden else (1+index) * height_step
		new_mesa.position.z = rng.randi_range(-boundary, boundary) * gap
		new_mesa.rotation.y = rng.randi_range(0, 3) * PI/2
		new_mesa.preference = new_mesa.Preference.none if hidden else new_mesa.Preference.deep
		new_mesa.size = random_size
		mesas.append(new_mesa)


@rpc("call_local", "reliable")
func clear_mesas():
	
	mesas = get_mesas()
	
	for mesa in mesas:
		mesa.queue_free()
			
	mesas.clear()	
	
	
func get_mesas():
	
	return find_children("*", "AnimatableBody3D", true, false)
	
