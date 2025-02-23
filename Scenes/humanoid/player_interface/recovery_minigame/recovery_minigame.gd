extends Control

@onready var fill = $Fill
@onready var backdrop = $BackDrop
@onready var target = $Target
@onready var lever = $Lever

@onready var net_sync = $CustomSync
@onready var unlagger = $LagCompensator

var progress = 0.0
var difficulty = 1.0

var lever_phase = 0.0

var locked = false

signal succeeded 
signal failed


func _ready():
	
	visible = false
	net_sync.get_net_var_delegate = get_net_vars
	net_sync.synced.connect(unlagger.reset)
	

func _process(delta):
	
	delta *= unlagger.delta_scalar(delta)
	lever_phase += delta * difficulty	
	
	if progress >= 1.0:
		early_succeed()

	target.visible = not locked
	lever.visible = not locked
	
	var total_length = backdrop.size.x
	var total_position = backdrop.position.x
	fill.size.x = total_length * progress
	fill.position.x = total_position * progress
	
	lever.position.x = sin(lever_phase) * total_length / 2.0
	
	if lever_on_target(lever_phase):
		target.color = Color('ffc354')
	else:
		target.color = Color('b98457')


func start():
	
	visible = true
	locked = false
			
			
func lever_on_target(phase):
	
	var simulated_position = sin(phase) * backdrop.size.x / 2.0
	return abs(simulated_position) <= target.size.x / 2.0
	
	
func attempt_early_recovery():
	
	if not is_multiplayer_authority():
		return
	elif locked: 
		early_fail.rpc()	
	elif lever_on_target(lever_phase):
		early_succeed.rpc()		
	else:
		early_fail.rpc()
	
	net_sync.force_sync()
		
		
@rpc("authority", "call_local")
func early_succeed():
	
	visible = false
	locked = false
	succeeded.emit()
	
@rpc("authority", "call_local")
func early_fail():
	
	locked = true
	failed.emit()
	
	
func get_net_vars():
	
	var net_vars = {}
	net_vars["lever_phase"] = lever_phase
	return net_vars
