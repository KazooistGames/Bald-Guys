extends Node

static var SERVER_PING = 0.0 
static var CLIENT_PINGS = {}

const max_state_age = 0.5
const debug = false

@onready var parent = get_parent()

var previous_transforms : Array = []
var previous_velocities : Array = []
var previous_state_ages : Array = []
	

func _physics_process(delta):
	
	if not is_multiplayer_authority():
		return

	for index in range(previous_state_ages.size()): #age every stored state
		previous_state_ages[index] += delta
	
	if previous_state_ages.size() == 0:
		pass
	elif previous_state_ages[0] >= max_state_age: #discard states that are too old
		previous_transforms.pop_front()
		previous_velocities.pop_front()
		previous_state_ages.pop_front()
	
	#previous_transforms.append(parent_state(PhysicsServer3D.BODY_STATE_TRANSFORM))
	#previous_velocities.append(parent_state(PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY))
	previous_transforms.append(get_parent().transform)
	previous_velocities.append(get_parent().linear_velocity)
	previous_state_ages.append(0)
	
	
func cache(age = 0):
	#print("cached new index ", previous_state_ages.size(), " with age of ", age)
	#previous_transforms.append(parent_state(PhysicsServer3D.BODY_STATE_TRANSFORM))
	#previous_velocities.append(parent_state(PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY))
	previous_transforms.append(get_parent().transform)
	previous_velocities.append(get_parent().linear_velocity)
	previous_state_ages.append(age)
	
	
func perform_rollback(time_to_rollback):
	
	var index = get_rollback_index(time_to_rollback)
	var rollback_velocity =  previous_velocities[index]
	var rollback_transform =  previous_transforms[index]
	parent.linear_velocity = rollback_velocity
	parent.transform = rollback_transform
	print("performed rollback to age ", previous_state_ages[index], " at index ", index)
	invalidate_cache_array(index)

	#return rollback_transform


func apply_retroactive_impulse(time_to_rollback, impulse, base_modifier : Callable = Callable(), delta_modifer: Callable = Callable(), use_gravity = true):
	
	var index = get_rollback_index(time_to_rollback)
	var base_velocity =  previous_velocities[index]
	var delta_velocity = previous_velocities[previous_velocities.size()-1] - base_velocity
	
	if base_modifier.is_valid():
		base_velocity = base_modifier.call(base_velocity)
		
	if delta_modifer.is_valid():
		delta_velocity = delta_modifer.call(delta_velocity)
	
	var starting_transform = previous_transforms[index]
	var predicted_transform = previous_transforms[index]
	var predicted_velocity = base_velocity + impulse + delta_velocity
	predicted_transform.origin += predicted_velocity * time_to_rollback 
	
	if debug:
		print("Rolled back ", time_to_rollback, " from " ,get_parent().transform.origin ," moving ", base_velocity, " at index ", index)
	
	if use_gravity:
		predicted_transform.origin -= Vector3.UP * 4.9 * pow(time_to_rollback, 2.0)		
		predicted_velocity -= Vector3.UP * 9.8 * time_to_rollback
		
	PhysicsServer3D.body_set_state(get_parent().get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, predicted_transform)
	PhysicsServer3D.body_set_state(get_parent().get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, predicted_velocity)
	invalidate_cache_array(index)
	mock_cache(starting_transform, predicted_velocity, time_to_rollback)
	
	if debug:
		print("wound up at ", predicted_transform.origin, " and set velocity to ", predicted_velocity)
	

func get_rollback_index(time_to_rollback):
	
	var newest_index = previous_state_ages.size() - 1
	var target_index = max(min(round(previous_state_ages.size() / 2.0), newest_index), 0)
	var age_at_index = previous_state_ages[target_index] 
	
	while(target_index > 0 and age_at_index < time_to_rollback): 
		target_index -= 1 	#give preference to more recent states	
		age_at_index = previous_state_ages[target_index] 	
	
	while(target_index < newest_index and age_at_index > time_to_rollback):
		target_index += 1
		age_at_index = previous_state_ages[target_index] 

	#print("found index ", target_index, ", with age ", age_at_index)
	return target_index


func get_rollback_velocity(time_to_rollback):
	
	var index = get_rollback_index(time_to_rollback)
	return previous_velocities[index]


func get_rollback_transfrom(time_to_rollback):
	
	var index = get_rollback_index(time_to_rollback)
	return previous_transforms[index]
	
	
func invalidate_cache_array(cutoff_index):
	
	#print("invalidated cache at index ", cutoff_index, ", newer than ", previous_state_ages[cutoff_index])
	previous_state_ages = previous_state_ages.slice(0, cutoff_index)
	previous_transforms = previous_transforms.slice(0, cutoff_index)
	previous_velocities = previous_velocities.slice(0, cutoff_index)
	
	
func clear_old_data(cutoff_age):
	
	var cutoff_index = get_rollback_index(cutoff_age)
	previous_state_ages = previous_state_ages.slice(cutoff_index)
	previous_transforms = previous_transforms.slice(cutoff_index)
	previous_velocities = previous_velocities.slice(cutoff_index)
	
	
func mock_cache(start_transform, velocity, time_span):
	
	var delta = 1.0 / Engine.physics_ticks_per_second
	
	while time_span > 0:
		previous_transforms.append(start_transform)
		previous_velocities.append(velocity)
		previous_state_ages.append(time_span)
		start_transform.origin += velocity * delta
		time_span -= delta


func parent_state(state_enum):
	
	var rid = get_parent().get_rid()
	var transform_state = PhysicsServer3D.body_get_state(rid, state_enum)
	return transform_state
