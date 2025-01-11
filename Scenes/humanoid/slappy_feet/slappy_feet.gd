extends AudioStreamPlayer3D

@onready var raycast = $RayCast3D


var triggered = false

var mod_db = 0.0
const base_db = -30.0

func process_slap(_delta):
	
	volume_db = base_db + mod_db
	
	rotation = Vector3.ZERO
	
	var object = raycast.get_collider()
	
	if not object:
		triggered = false
		
	elif not triggered:
		triggered = distance() < threshold()
		
		if triggered:
			play()
		

func threshold():
	return raycast.target_position.length()/2
	
	
func distance():
	return (raycast.get_collision_point() - global_position).length()
