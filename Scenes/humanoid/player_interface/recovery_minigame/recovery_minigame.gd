extends Control

const lever_speed = 2.0
const base_target_size = 100

@onready var fill = $Fill
@onready var backdrop = $BackDrop
@onready var target = $Target
@onready var lever = $Lever


var progress = 0.0
var difficulty = 1.0
var locked = false

signal succeeded 
signal failed


func _ready():
	
	visible = false


func _process(delta):
	
	if progress >= 1.0:
		early_succeed()

	target.visible = not locked
	lever.visible = not locked
	target.size.x = base_target_size / difficulty
	target.position.x = -target.size.x/2.0
	var total_length = backdrop.size.x
	var total_position = backdrop.position.x
	fill.size.x = total_length * progress
	fill.position.x = total_position * progress
	
	lever.position.x = sin(lever_speed * Time.get_unix_time_from_system()) * total_length / 2.0
	
	if lever_on_target(Time.get_unix_time_from_system(), difficulty):
		target.color = Color('ffc354')
	else:
		target.color = Color('b98457')


func start_game():
	
	visible = true
	locked = false
			
			
func lever_on_target(timestamp, difficulty = 1.0):
	
	var simulated_position = sin(lever_speed * timestamp) * backdrop.size.x / 2.0
	return abs(simulated_position) <= base_target_size / (2.0 * difficulty)
	
	
func attempt_early_recovery(unix_time):
	
	if not is_multiplayer_authority():
		return
	elif locked: 
		early_fail.rpc()	
	elif lever_on_target(unix_time, 1.0):
		early_succeed.rpc()		
	else:
		early_fail.rpc()
		
		
@rpc("authority", "call_local")
func early_succeed():
	
	visible = false
	locked = false
	succeeded.emit()
	
	
@rpc("authority", "call_local")
func early_fail():
	
	locked = true
	failed.emit()
	
