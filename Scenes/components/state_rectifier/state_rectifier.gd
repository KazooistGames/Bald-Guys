extends Node

static var SERVER_PING = 0.0 
static var CLIENT_PINGS = {}

const max_state_age = 1.0
const debug = false

var previous_transforms : Array = []
var previous_velocities : Array = []
var previous_state_ages : Array = []
	

func _physics_process(delta):
	
	for index in range(previous_state_ages.size()):
		previous_state_ages[index] += delta
		
	previous_transforms.append(parent_state(PhysicsServer3D.BODY_STATE_TRANSFORM))
	previous_velocities.append(parent_state(PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY))
	previous_state_ages.append(0)
	
	if previous_state_ages[0] >= max_state_age:
		previous_transforms.pop_front()
		previous_velocities.pop_front()
		previous_state_ages.pop_front()
	

func apply_retroactive_impulse(time_to_rollback, impulse, base_modifier : Callable = Callable(), delta_modifer: Callable = Callable(), use_gravity = true):
	
	var index = get_rollback_index(time_to_rollback)
	var base_velocity =  previous_velocities[index]
	var delta_velocity = previous_velocities[previous_velocities.size()-1] - base_velocity
	
	if base_modifier.is_valid():
		base_velocity = base_modifier.call(base_velocity)
		
	if delta_modifer.is_valid():
		delta_velocity = delta_modifer.call(delta_velocity)
		
	var predicted_velocity = base_velocity + delta_velocity + impulse
	var predicted_transform = previous_transforms[index]
	predicted_transform.origin += predicted_velocity * time_to_rollback 
	
	if debug:
		print("Rolled back ", time_to_rollback, " from " ,get_parent().transform.origin ," moving ", base_velocity, " at index ", index)
	
	if use_gravity:
		predicted_transform.origin -= Vector3.UP * 4.9 * pow(time_to_rollback, 2.0)		
		predicted_velocity -= Vector3.UP * 9.8 * time_to_rollback
		
	PhysicsServer3D.body_set_state(get_parent().get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, predicted_transform)
	PhysicsServer3D.body_set_state(get_parent().get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, predicted_velocity)
	invalidate_cache_array(index)
	
	if debug:
		print("wound up at ", predicted_transform.origin, " and set velocity to ", predicted_velocity)
	

func get_rollback_index(time_to_rollback):
	
	var target_index = round(previous_state_ages.size() / 2.0)
	var newest_index = previous_state_ages.size() - 1
	
	while(target_index > 0 and previous_state_ages[target_index] < time_to_rollback): 
		target_index -= 1 	#give preference to more recent states		
	while(target_index <= newest_index and previous_state_ages[target_index] > time_to_rollback):
		target_index += 1
	
	return target_index


func get_rollback_velocity(time_to_rollback):
	
	var index = get_rollback_index(time_to_rollback)
	return previous_velocities[index]


func get_rollback_transfrom(time_to_rollback):
	
	var index = get_rollback_index(time_to_rollback)
	return previous_transforms[index]
	

func get_cumulative_transform_change(start_index):
	
	for index in range(start_index, 0):
		pass
	
	
func invalidate_cache_array(start_index):
	
	previous_state_ages = previous_state_ages.slice(start_index)
	previous_transforms = previous_transforms.slice(start_index)
	previous_velocities = previous_velocities.slice(start_index)


func parent_state(state_enum):
	
	var rid = get_parent().get_rid()
	var transform_state = PhysicsServer3D.body_get_state(rid, state_enum)
	return transform_state
