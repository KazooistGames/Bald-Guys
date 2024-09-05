extends Node3D

const camera_prefab = preload("res://Scenes/cameras/FPS_Camera.tscn")

@export var character : Node3D

@export var camera : Node3D

@onready var CAMERA_OFFSET = 0.11


func _ready():
	pass
	
	
func _process(_delta):
	
	if not character:
		camera = null
		
	elif not camera:
		camera = camera_prefab.instantiate()
		character.add_child(camera)
		
	else:
		CAMERA_OFFSET = -1.5 if character.MOVE_STATE == character.MoveState.RAGDOLL else 0.115
		var adjustedOffset = character.LOOK_VECTOR.normalized().rotated(Vector3.UP, PI) * CAMERA_OFFSET
		var adjustedPosition = character.head_position()
		camera.position = adjustedPosition + adjustedOffset
	
	
func _unhandled_input(event):
	
	if character and camera:	
		handle_mouse(event)
		handle_keyboard(event)


func handle_mouse(_event):
	
	var look = Vector3(sin(camera.rotation.y), camera.rotation.x, cos(camera.rotation.y))
	character.LOOK_VECTOR = look
	character.Main_Trigger = Input.is_action_pressed("main")
	camera.HORIZONTAL_SENSITIVITY = 0.002 if character.Main_Trigger else 0.005
	
	
func handle_keyboard(_event):
	
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	direction = direction.rotated(Vector3.UP, camera.rotation.y)
	character.WALK_VECTOR = direction  
	
	if Input.is_action_just_pressed("jump"):
		character.jump.rpc()
	
	if Input.is_action_pressed("run"):
		character.RUNNING = true
	
	elif Input.is_action_just_released("run"):
		character.RUNNING = false
		
	if Input.is_action_just_pressed("equip"):
		character.ragdoll.rpc()
	
	if Input.is_action_just_pressed("drop"):
		character.unragdoll.rpc()
