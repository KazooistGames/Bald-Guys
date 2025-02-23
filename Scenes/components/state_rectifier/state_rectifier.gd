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
			

func parent_state(state_enum):
	
	var rid = get_parent().get_rid()
	var transform_state = PhysicsServer3D.body_get_state(rid, state_enum)
	return transform_state
	

func rollback_transform(time_to_rollback):
	
	var target_index = round(previous_state_ages.size() / 2.0)
	var oldest_index = previous_state_ages.size()
		
	while(target_index <= oldest_index - 1 and previous_state_ages[target_index] < time_to_rollback):
		target_index += 1
		
	while(target_index > 0 and previous_state_ages[target_index] > time_to_rollback): #give preference to more recent states
		target_index -= 1 
		
	var rid = get_parent().get_rid()
	var target_transform = previous_transforms[target_index]
	
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, target_transform)
	invalidate_cache_array(target_index)
	

func rollback_velocity(time_to_rollback):
	
	var target_index = round(previous_state_ages.size() / 2.0)
	var oldest_index = previous_state_ages.size() - 1
		
	while(previous_state_ages[target_index] < time_to_rollback and target_index > 0 ): 
		target_index -= 1 
		
	#give preference to more recent states
	while(previous_state_ages[target_index] > time_to_rollback and target_index <= oldest_index):
		target_index += 1 
		
	var rid = get_parent().get_rid()
	var target_transform = previous_transforms[target_index]
	
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, target_transform)
	invalidate_cache_array(target_index)

	
func invalidate_cache_array(start_index):
	
	previous_state_ages = previous_state_ages.slice(start_index)
	previous_transforms = previous_transforms.slice(start_index)
	previous_velocities

