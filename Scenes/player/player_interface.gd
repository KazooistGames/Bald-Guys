extends Node3D

const camera_prefab = preload("res://Scenes/cameras/FPS_Camera.tscn")
#const force_prefab = preload("res://Scenes/force/force.tscn")

@export var character : Node3D

@export var camera : Node3D

@export var force : Node3D

@export var targeted_object : Node3D
	
	
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
		character.REACHING = force.action #enumerations are lined up via integer values
		camera.HORIZONTAL_SENSITIVITY = 0.002 if character.REACHING else 0.004
		force.Aim = (character.LOOK_VECTOR * Vector3(-1, 1, -1)).normalized()
		var offset_to_zero = 1.0 - abs(character.LOOK_VECTOR.normalized().dot(Vector3.UP))
		force.base_position = camera.position.lerp(Vector3.ZERO, offset_to_zero * 0.33)
		force.rotation = camera.rotation 	


	
func movement():
	
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	direction = direction.rotated(Vector3.UP, camera.rotation.y)
	character.WALK_VECTOR = direction
	character.RUNNING = Input.is_action_pressed("run")
	
	if character.RAGDOLLED:
		return
	elif Input.is_action_just_pressed("jump"):
		character.jump.rpc()
	

	

	
		
func aiming():
	
	var cam_depth = -1.5 if character.RAGDOLLED else 0.115
	var adjustedOffset = character.LOOK_VECTOR.normalized().rotated(Vector3.UP, PI) * cam_depth
	var adjustedPosition = character.head_position()
	camera.position = adjustedPosition + adjustedOffset	
	var look = Vector3(sin(camera.rotation.y), camera.rotation.x, cos(camera.rotation.y))
	character.LOOK_VECTOR = look
	

		
	targeted_object = camera.raycast.get_collider()
	
	
func abilities():
	
	force.external_velocity = character.linear_velocity
	
	if force.action == force.Action.inert:
		camera.Locked = false
		
	elif force.action == force.Action.charging:
		camera.Locked = true
		character.RUNNING = false
		character.WALK_VECTOR = Vector3.ZERO
		
	elif force.action == force.Action.cooldown:
		character.RUNNING = false
		camera.Locked = false
	
	if Input.is_action_just_pressed("equip"):
		character.ragdoll.rpc()
	
	if Input.is_action_just_pressed("drop"):
		character.unragdoll.rpc()
	
	if character.RAGDOLLED:
		force.rpc_reset.rpc()
		return
	
	if Input.is_action_just_pressed("secondary"):
		force.rpc_secondary.rpc()
		
	elif Input.is_action_just_released("secondary"):
		force.rpc_reset.rpc()
		
	if Input.is_action_just_pressed("primary"):
		
		if force.action == force.Action.holding:
			force.rpc_trigger.rpc()
		
		elif force.action == force.Action.cooldown:
			pass
		
		else:
			force.rpc_primary.rpc()
			
			if targeted_object != null:
				var disposition = targeted_object.global_position - character.global_position
				var distance = disposition.length()
				
				if distance > 4:
					pass
					
				elif targeted_object.is_in_group("humanoids"):
					var lunge_velocity = disposition.normalized() * distance * 3.5
					character.lunge.rpc(lunge_velocity)
					#character.linear_velocity = disposition.normalized() * distance * 3.5
			
		
	

