extends Node

static var SERVER_PING = 0.0 :
	get:
		return SERVER_PING
	set(value):
		SERVER_PING = lerpf(SERVER_PING, value, 0.5)
		
static var CLIENT_PINGS = { 1 : 0}

var remaining_time_to_being_rectified = 0.0
var max_rectification_scalar = 1.1

var current_delta_scalar = 1.0
var current_compensated_delta = 0.0

signal triggered(ping)


func delta_scalar(delta): #use per-frame, auto decays 
	
	var instant_fix_scalar = 1.0 + remaining_time_to_being_rectified / delta
	var return_val = minf(instant_fix_scalar, max_rectification_scalar)
	current_delta_scalar = return_val
	remaining_time_to_being_rectified -= (current_delta_scalar - 1.0) * delta
	
	return return_val	
		

func compensated_delta(delta):
	
	var scaled_delta = delta * 1.1
	var return_val = minf(scaled_delta, remaining_time_to_being_rectified + delta)
	current_compensated_delta = return_val
	remaining_time_to_being_rectified -= (current_compensated_delta - delta)
	return return_val


func reset(client_id = 1):
	
	if is_multiplayer_authority():
		if CLIENT_PINGS.has(client_id):
			remaining_time_to_being_rectified = CLIENT_PINGS[client_id] / 1000.0
	else:
		remaining_time_to_being_rectified = SERVER_PING / 1000.0
		
		
func reset_full_duplex(client_id = 1):
	
	if is_multiplayer_authority():
		if CLIENT_PINGS.has(client_id):
			remaining_time_to_being_rectified = CLIENT_PINGS[client_id] / 500.0
	else:
		remaining_time_to_being_rectified = SERVER_PING / 500.0


func parent_state():
	var rid = get_parent().get_rid()
	var transform_state = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM)
	return transform_state


func trigger(manual_ping):
	
	triggered.emit(manual_ping)
