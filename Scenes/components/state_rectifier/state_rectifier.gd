extends Node

const max_state_age = 0.5
const debug = false

@export var StateKeys : Array[String] = []
@export var Whitelist : Array[String] = []
@export var Blacklist : Array[String] = []

@onready var parent = get_parent()

var previous_ages : Array[float] = []
var previous_states : Array[Dictionary]
	
	
func _physics_process(delta):
	
	if not multiplayer.has_multiplayer_peer():
		return
	elif not is_multiplayer_authority():
		return

	for index in range(previous_ages.size()): #age every stored state
		previous_ages[index] += delta
	
	if previous_ages.size() == 0:
		pass
	elif previous_ages[0] >= max_state_age: #discard states that are too old

		previous_states.pop_front()
		previous_ages.pop_front()
	
	cache(0)
	
	
func cache(age = 0, blacklist : Array[String] = [], whitelist : Array[String] = [], debug = false):

	previous_ages.append(age)
	
	var state : Dictionary = {}
	
	for key in StateKeys:		
		var key_allowed = true
		
		if blacklist.has(key):
			key_allowed = false
		elif not whitelist.has(key) and not whitelist.is_empty():
			key_allowed = false
			
		if key_allowed:
			state[key] = parent.get(key)
		
		if debug:
			print("cached  ", parent.name, " ", key, " at ", state[key])
			
		
	previous_states.append(state)
		
	
func perform_rollback(time_to_rollback, blacklist : Array= [], whitelist : Array = [], debug = false):
	
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
			
		if key_allowed:
			parent.set(key, state[key])
		
			if debug:
				print("rolled back ", parent.name, " ", key, " to ", state[key])
	
	invalidate_cache_array(index)


func get_rollback_index(time_to_rollback):
	
	if previous_ages.size() == 0:
		return -1
		
	var newest_index = previous_ages.size() - 1
	var target_index = max(min(round(previous_ages.size() / 2.0), newest_index), 0)
	var age_at_index = previous_ages[target_index] 
	
	while(target_index > 0 and age_at_index < time_to_rollback): 
		target_index -= 1 	#give preference to more recent states	
		age_at_index = previous_ages[target_index] 	
	
	while(target_index < newest_index and age_at_index > time_to_rollback):
		target_index += 1
		age_at_index = previous_ages[target_index] 

	#print("found index ", target_index, ", with age ", age_at_index)
	return target_index

	
func get_rollback_state(time_to_rollback):
	
	var index = get_rollback_index(time_to_rollback)
	return previous_states[index]	


func invalidate_cache_array(cutoff_index):
	
	#print("invalidated cache at index ", cutoff_index, ", newer than ", previous_ages[cutoff_index])
	if cutoff_index < previous_ages.size() - 1:
		cutoff_index += 1
		
	previous_ages = previous_ages.slice(0, cutoff_index)
	previous_states = previous_states.slice(0, cutoff_index)
	
	
func clear_old_data(cutoff_age):
	
	var cutoff_index = get_rollback_index(cutoff_age)
	previous_ages = previous_ages.slice(cutoff_index)
	previous_states = previous_states.slice(cutoff_index)


func parent_state(state_enum : PhysicsServer3D.BodyState) -> Transform3D:
	
	var rid : RID = get_parent().get_rid()
	var transform_state : Transform3D = PhysicsServer3D.body_get_state(rid, state_enum)
	return transform_state
