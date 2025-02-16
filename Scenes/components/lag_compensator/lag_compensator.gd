extends Node3D

static var GLOBAL_PING = 0.0 # this clients ping ms set by top of hierarchy

var remaining_time_to_being_rectified = 0.0
var max_rectification_scalar = 2.0 

var current_delta_scalar = 1.0
var current_compensated_delta = 0.0


func _process(delta):
	
	#current_delta_scalar = delta_scalar(delta)
	current_compensated_delta = compensated_delta(delta)
	
	if is_multiplayer_authority():
		pass
	else:
		print(remaining_time_to_being_rectified, "	", delta, "  ", current_compensated_delta)
	
	remaining_time_to_being_rectified -= (current_compensated_delta - delta)
	

func delta_scalar(delta):
	
	var instant_fix_scalar = 1.0 + remaining_time_to_being_rectified / delta
	var return_val = minf(instant_fix_scalar, max_rectification_scalar)
	return return_val	
		

func compensated_delta(delta):
	
	var scaled_delta = delta * 1.1
	
	var return_val = minf(scaled_delta, remaining_time_to_being_rectified + delta)
		
	return return_val


func reset_rectification():
	
	remaining_time_to_being_rectified = GLOBAL_PING / 1000.0



