extends AudioStreamPlayer3D

const base_db = -40.0
const speed_threshold = 1.0
const dot_threshold = 0.0
const squeek_duration = 0.25
const squeek_deadband = 0.5
const squeek_seek_locations : Array[float] = [
	7.20,
	7.45,
	9.45,
	11,
	12.4,
	13.2,
	14.5,
	17.3,
	20,
	22.65,
	24.05,
	26.05
	]

@onready var raycast = $RayCast3D
@onready var humanoid = $"../../../.."
@onready var squeek_sound = $SqueekAudio

var triggered = false

var mod_db = 0.0
var direction : Vector3
var velocity : Vector3

var squeek_timer = squeek_duration
var squeek_deadband_timer = 0.0

func _ready():
	
	squeek_sound.play()
	squeek_sound.stream_paused = true
	

func process_slap(delta):
	
	volume_db = base_db + mod_db
	rotation = Vector3.ZERO	
	
	direction = humanoid.WALK_VECTOR
	velocity = humanoid.linear_velocity
	
	var floor_collider = raycast.get_collider()
	
	if squeek_deadband_timer < squeek_deadband: #deadband for repeat squeeks
		squeek_deadband_timer += delta
	
	if squeek_timer >= squeek_duration:
		squeek_sound.stream_paused = true
	else:
		squeek_timer += delta
	
	if not floor_collider:
		triggered = false

	elif not triggered:
		triggered = distance() < threshold()
		
		if triggered:
			play()
			check_squeek()
				

func threshold():
	return raycast.target_position.length()/2
	
	
func distance():
	return (raycast.get_collision_point() - global_position).length()


func check_squeek():
	
	if velocity.length() < speed_threshold:
		pass
		
	elif velocity.normalized().dot(direction.normalized()) < dot_threshold:
		squeek()
		squeek_deadband_timer = 0.0
		
	elif squeek_deadband_timer < squeek_deadband:
		squeek()
	
	
func squeek():

	squeek_timer = 0.0
	var seek_to = squeek_seek_locations.pick_random()
	squeek_sound.stream_paused = false
	squeek_sound.seek(seek_to)
	
	
