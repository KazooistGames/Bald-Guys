extends Node3D

const camera_prefab = preload("res://Scenes/cameras/FPS_Camera.tscn")
const force_prefab = preload("res://Scenes/humanoid/force/force.tscn")

@export var character : Node3D

@export var camera : Node3D

@export var force : Node3D
	
	
func _process(_delta):
	
	if not character:
		
		if camera:
			camera.queue_free()
		
		camera = null
		
	elif not camera:
		camera = camera_prefab.instantiate()
		character.add_child(camera)
		
	else:
		var cam_depth = -1.5 if character.RAGDOLLED else 0.115
		var adjustedOffset = character.LOOK_VECTOR.normalized().rotated(Vector3.UP, PI) * cam_depth
		var adjustedPosition = character.head_position()
		camera.position = adjustedPosition + adjustedOffset
		
		var look = Vector3(sin(camera.rotation.y), camera.rotation.x, cos(camera.rotation.y))
		character.LOOK_VECTOR = look
		camera.HORIZONTAL_SENSITIVITY = 0.002 if character.REACHING else 0.004
		

		var input_dir = Input.get_vector("left", "right", "forward", "backward")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		direction = direction.rotated(Vector3.UP, camera.rotation.y)
		character.WALK_VECTOR = direction
	
		character.REACHING = Input.is_action_pressed("main")
		character.RUNNING = Input.is_action_pressed("run")
			
		if Input.is_action_just_pressed("jump"):
			character.FLOATING = true
			character.jump.rpc()
			
		elif Input.is_action_just_released("jump"):
			character.FLOATING = false
			
		if Input.is_action_just_pressed("equip"):
			character.ragdoll.rpc()
		
		if Input.is_action_just_pressed("drop"):
			character.unragdoll.rpc()
	

	
