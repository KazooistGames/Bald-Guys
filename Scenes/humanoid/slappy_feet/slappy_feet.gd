extends AudioStreamPlayer3D

@onready var raycast = $RayCast3D


var triggered = false


func process_slap(delta):
	
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
