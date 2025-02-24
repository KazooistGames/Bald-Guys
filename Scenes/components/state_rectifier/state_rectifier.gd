extends Node

static var SERVER_PING = 0.0 
static var CLIENT_PINGS = {}

const max_state_age = 0.5

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
	

func apply_rollback_velocity(time_to_rollback, velocity_delta_to_apply, velocity_mask = Vector3.ONE):
	
	var index = get_rollback_index(time_to_rollback)
	var predictive_rollback_transform = previous_transforms[index]
	
	#print(previous_state_ages)
	print("Rolled back ", time_to_rollback, " from " ,get_parent().transform.origin ," to ", predictive_rollback_transform.origin, " at index ", index)
	var starting_velocity =  previous_velocities[previous_velocities.size()-1]
	while index < previous_velocities.size() - 1:
		var time_delta = previous_state_ages[index] - previous_state_ages[index + 1]
		var reapplied_velocity = previous_velocities[index] * time_delta * velocity_mask
		predictive_rollback_transform.origin += reapplied_velocity
		
		index += 1
	predictive_rollback_transform.origin += velocity_delta_to_apply * time_to_rollback
	predictive_rollback_transform.origin -= Vector3.UP * 4.9 * pow(time_to_rollback, 2.0)
		
	velocity_delta_to_apply -= Vector3.UP * 9.8 * time_to_rollback
	velocity_delta_to_apply += starting_velocity
	PhysicsServer3D.body_set_state(get_parent().get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, predictive_rollback_transform)
	PhysicsServer3D.body_set_state(get_parent().get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, velocity_delta_to_apply)
	print("wound up at ", predictive_rollback_transform.origin, " and set velocity to ", velocity_delta_to_apply)
	invalidate_cache_array(index)
	

func get_rollback_index(time_to_rollback):
	
	var target_index = round(previous_state_ages.size() / 2.0)
	var newest_index = previous_state_ages.size() - 1

	while(target_index <= newest_index and previous_state_ages[target_index] > time_to_rollback):
		target_index += 1
	while(target_index > 0 and previous_state_ages[target_index] < time_to_rollback): 
		target_index -= 1 	#give preference to more recent states			
		
	return target_index


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
