extends Camera3D

const MAX_ANGLE = PI/2.3

@export var VERTICAL_SENSATIVITY = 0.005
@export var HORIZONTAL_SENSITIVITY = 0.005
@export var Locked = false

@onready var reticle = $reticle
@onready var raycast = $RayCast3D
@onready var shapecast = $ShapeCast3D

@onready var postprocessing = $postprocessing


func _ready():
	
	set_current(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	
func _process(_delta):
	
	reticle.expand_mode = 1
	reticle.size = Vector2.ONE * 4
	reticle.position = get_center_of_screen() - reticle.size/2.0
	
	
func _input(event):
	
	set_current(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if Locked:
		pass
	elif event is InputEventMouseMotion:
		rotate_y(-event.relative.x * HORIZONTAL_SENSITIVITY )
		rotate_object_local(Vector3(1,0,0), -event.relative.y * VERTICAL_SENSATIVITY)
		rotation.x = clamp(rotation.x, -MAX_ANGLE, MAX_ANGLE)
		rotation.y = fmod(rotation.y, 2 * PI)
		rotation.z = 0


func get_center_of_screen():
	
	var lookPoint = raycast.get_collision_point()
	var screenCenter = unproject_position(lookPoint)
	screenCenter.x = snapped(screenCenter.x, 1)
	screenCenter.y = snapped(screenCenter.y, 1)
	return screenCenter
	
