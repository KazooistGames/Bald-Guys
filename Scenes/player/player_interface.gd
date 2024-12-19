extends Node3D

const camera_prefab = preload("res://Scenes/cameras/FPS_Camera.tscn")
#const force_prefab = preload("res://Scenes/force/force.tscn")

@export var character : Node3D

@export var camera : Node3D

@export var force : Node3D
	
	
func _process(_delta):
	
	if not character:	
		camera = null
		
	elif not camera:
		camera = camera_prefab.instantiate()
		character.add_child(camera)
		
	else:
		movement()
		aiming()
		abilities()		
		character.REACHING = force.action != force.Action.inert
		camera.HORIZONTAL_SENSITIVITY = 0.002 if character.REACHING else 0.004
		force.position = camera.position 
		force.rotation = camera.rotation 	
		
		if force.action != force.Action.inert:
			force.position = force.position.lerp(Vector3.ZERO, 0.25)
			force.position += force.Aim * 1.25	
		else:
			force.position -= force.Aim * 1.25			

	
func movement():
	
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	direction = direction.rotated(Vector3.UP, camera.rotation.y)
	character.WALK_VECTOR = direction
	character.RUNNING = Input.is_action_pressed("run")
	
	if Input.is_action_just_pressed("jump"):
		character.jump.rpc()
	
		
func aiming():
	
	var cam_depth = -1.5 if character.RAGDOLLED else 0.115
	var adjustedOffset = character.LOOK_VECTOR.normalized().rotated(Vector3.UP, PI) * cam_depth
	var adjustedPosition = character.head_position()
	camera.position = adjustedPosition + adjustedOffset	
	var look = Vector3(sin(camera.rotation.y), camera.rotation.x, cos(camera.rotation.y))
	character.LOOK_VECTOR = look
	force.Aim = (look * Vector3(-1, 1, -1)).normalized()
	
	
func abilities():
	
	if Input.is_action_just_pressed("secondary"):
		force.action = force.Action.holding
		
	elif Input.is_action_just_released("secondary"):
		force.action = force.Action.inert
		
	if Input.is_action_just_pressed("primary"):
		
		if force.action == force.Action.holding:
			force.rpc_trigger.rpc()
		else:
			force.action = force.Action.charging	
		
	if Input.is_action_just_pressed("equip"):
		character.ragdoll.rpc()
	
	if Input.is_action_just_pressed("drop"):
		character.unragdoll.rpc()
