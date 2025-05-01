extends Camera3D

const MAX_ANGLE = PI/2.3

const DRIVING_DISTANCE = -2.0
const RAGDOLLED_DISTANCE = -3.0

@export var Locked = false

@onready var reticle = $reticle
@onready var raycast = $RayCast3D
@onready var shapecast = $ShapeCast3D
@onready var postprocessing = $postprocessing

@onready var humanoid = get_parent()
@onready var force = humanoid.find_child("Force")

var VERTICAL_SENSATIVITY = 0.005
var HORIZONTAL_SENSITIVITY = 0.005

var is_local_camera = false

func _ready():

	add_to_group("cameras")
	
	is_local_camera = str(multiplayer.get_unique_id()) == humanoid.name
	current = is_local_camera
	reticle.visible = is_local_camera
	
	
func _process(_delta):
	
	if is_local_camera:
		reticle.expand_mode = 1
		reticle.size = Vector2.ONE * 4	
		reticle.position = get_center_of_screen() - reticle.size/2.0
		
	HORIZONTAL_SENSITIVITY = 0.002 if humanoid.REACHING else 0.004
	var cam_depth = RAGDOLLED_DISTANCE if humanoid.RAGDOLLED else DRIVING_DISTANCE
	var adjustedOffset = humanoid.LOOK_VECTOR.normalized().rotated(Vector3.UP, PI) * cam_depth
	var adjustedPosition = humanoid.head_position()
	position = adjustedPosition + adjustedOffset	
	
	if force.action == force.Action.inert:
		Locked = false	
	elif force.action == force.Action.charging:
		Locked = true		
	elif force.action == force.Action.cooldown:
		Locked = false


func rotate_by_relative_delta(relative_delta):
	
	if Locked:
		pass
	else:
		rotate_y(-relative_delta.x * HORIZONTAL_SENSITIVITY )
		rotate_object_local(Vector3(1,0,0), -relative_delta.y * VERTICAL_SENSATIVITY)
		rotation.x = clamp(rotation.x, -MAX_ANGLE, MAX_ANGLE)
		rotation.y = fmod(rotation.y, 2 * PI)
		rotation.z = 0
		
	return rotation


func get_center_of_screen():
	
	var lookPoint = raycast.get_collision_point()
	var screenCenter = unproject_position(lookPoint)
	screenCenter.x = snapped(screenCenter.x, 1)
	screenCenter.y = snapped(screenCenter.y, 1)
	return screenCenter
	
