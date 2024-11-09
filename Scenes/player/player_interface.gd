extends Node3D

const camera_prefab = preload("res://Scenes/cameras/FPS_Camera.tscn")

@export var character : Node3D

@export var camera : Node3D

@onready var CAMERA_OFFSET = 0.11
	
	
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
		var look = Vector3(sin(camera.rotation.y), camera.rotation.x, cos(camera.rotation.y))
		character.LOOK_VECTOR = look
		camera.HORIZONTAL_SENSITIVITY = 0.002 if character.REACHING else 0.004
		character.REACHING = Input.is_action_pressed("main")
		
	
func _unhandled_input(event):
	
	if character and camera:	
		var input_dir = Input.get_vector("left", "right", "forward", "backward")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		direction = direction.rotated(Vector3.UP, camera.rotation.y)
		character.WALK_VECTOR = direction
		
		if Input.is_action_just_pressed("run"):
			character.RUNNING = !character.RUNNING
		
		if Input.is_action_just_pressed("jump"):
			character.FLOATING = true
			character.jump.rpc()
		elif Input.is_action_just_released("jump"):
			character.FLOATING = false
			
		if Input.is_action_just_pressed("equip"):
			character.ragdoll.rpc()
		
		if Input.is_action_just_pressed("drop"):
			character.unragdoll.rpc()

	
