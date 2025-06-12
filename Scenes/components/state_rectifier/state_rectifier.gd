extends Node

const max_state_age = 0.5
const debug = false

@export var StateKeys : Array[String] = []

@onready var parent = get_parent()

var previous_ages : Array[float] = []
var previous_states : Array[Dictionary]
	
	
func _ready():
	
	previous_states.resize(floor(1.0 / get_physics_process_delta_time()))
	
	
func _physics_process(_delta):

	if not multiplayer.has_multiplayer_peer():
		return
	elif not is_multiplayer_authority():
		return
	
	var new_frame = {}
	
	for key in StateKeys:
		new_frame[key] = parent.get(key)
		
	previous_states.push_front(new_frame)
	previous_states.pop_back()
	
	
func update_cache(age = 0, blacklist : Array = [], whitelist : Array = []):

	var index = get_rollback_index(age)
	
	for key in StateKeys:		
		var key_allowed = true
		
		if blacklist.has(key):
			key_allowed = false
		elif not whitelist.has(key) and not whitelist.is_empty():
			key_allowed = false
			
		if key_allowed:
			previous_states[index][key] = parent.get(key)

			if debug:
				print("updated ", parent.name, " ", key, " to ", previous_states[index][key], " at frame -", index)
			
		
	
func perform_rollback(time_to_rollback, blacklist : Array = [], whitelist : Array = []):
	
	var index = get_rollback_index(time_to_rollback)
	
	if index < 0:
		return
		
	var state = get_rollback_state(time_to_rollback)
	
	for key in StateKeys:			
		var key_allowed = true
		
		if blacklist.has(key):
			key_allowed = false
		elif not whitelist.has(key) and not whitelist.is_empty():
			key_allowed = false
			
		if key_allowed and state.has(key):
			parent.set(key, state[key])
		
			if debug:
				print("rolled back ", parent.name, " ", key, " to ", state[key])
	
	#invalidate_cache_array(index)


func get_rollback_index(time_to_rollback):
	
	return floor(time_to_rollback / get_physics_process_delta_time())

	
func get_rollback_state(time_to_rollback):
	
	var index = get_rollback_index(time_to_rollback)
	return previous_states[index]	


