extends Node

static var SERVER_PING = 0.0 
static var CLIENT_PINGS = {}

const max_state_age = 0.5

var previous_state : Array = []
var previous_state_age : Array = []
	

func _physics_process(delta):
	
	for index in range(previous_state.size()):
		previous_state_age[index] += delta
		
	previous_state.append(parent_state())
	previous_state_age.append(0)
	
	if previous_state_age[0] >= max_state_age:
		previous_state.pop_front()
		previous_state_age.pop_front()
			
	

func parent_state():
	var rid = get_parent().get_rid()
	var transform_state = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM)
	return transform_state


