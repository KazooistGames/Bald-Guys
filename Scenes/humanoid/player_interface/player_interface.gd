extends Node

@export var humanoid : Node3D
@export var camera : Node3D
@export var force : Node3D
@export var targeted_object : Node3D

@onready var recovery_minigame = $RecoveryMinigame
var WASD = Vector2.ZERO

var is_local_interface = false

var cached_inputs = {} #used to determine delta across the network
	
	
func _ready():

	add_to_group("interfaces")
	humanoid = get_parent()
	force = humanoid.find_child("Force")
	camera = humanoid.find_child("Camera*")
	humanoid.ragdolled.connect(react_to_ragdoll)
	humanoid.unragdolled.connect(react_to_ragdoll_recovery)
	recovery_minigame.succeeded.connect(react_early_recovery)
	

func _process(delta):
			
	var ragdoll_speed = humanoid.find_child("*lowerBody", true, false).linear_velocity.length()
	recovery_minigame.difficulty = pow(max(humanoid.ragdoll_recovery_default_duration, ragdoll_speed), 0.5)
	recovery_minigame.progress = humanoid.ragdoll_recovery_progress
	
	
func _physics_process(_delta):	
	
	#if is_multiplayer_authority():
	var direction = (Basis.IDENTITY * Vector3(WASD.x, 0, WASD.y)).normalized()
	humanoid.WALK_VECTOR =  direction.rotated(Vector3.UP, camera.rotation.y)
	humanoid.REACHING = force.action
	humanoid.LOOK_VECTOR = Vector3(sin(camera.rotation.y), camera.rotation.x, cos(camera.rotation.y))
	force.Aim = (humanoid.LOOK_VECTOR * Vector3(-1, 1, -1)).normalized()
	var offset_to_zero = 1.0 - abs(humanoid.LOOK_VECTOR.normalized().dot(Vector3.UP))
	force.base_position = camera.position.lerp(Vector3.ZERO, offset_to_zero * 0.33)
	force.rotation = camera.rotation 
	
	if camera.shapecast.is_colliding():
		targeted_object = camera.shapecast.get_collider(0)
		
	if not multiplayer.has_multiplayer_peer():
		return
		
	is_local_interface = str(multiplayer.get_unique_id()) == humanoid.name

	if is_local_interface:	
		camera.current = true	
		var continuous_inputs = {}
		continuous_inputs['direction'] = Input.get_vector("left", "right", "forward", "backward")
		WASD = continuous_inputs['direction']
		continuous_inputs['run'] = Input.is_action_pressed("run")
		#humanoid.RUNNING = continuous_inputs['run']
		rpc_send_Continuous_input.rpc_id(get_multiplayer_authority(), continuous_inputs)
			
	
func _input(event):
	
	if not is_local_interface:
		return
	
	elif event is InputEventMouseMotion:
		camera.rotate_by_relative_delta(event.relative)
		rpc_send_aim_input.rpc_id(get_multiplayer_authority(), event.relative)
				
	else:
		var discrete_inputs = {}
		discrete_inputs['jump'] = Input.is_action_pressed("jump")
		discrete_inputs["recover"] = Input.is_action_pressed("recover")
		discrete_inputs["primary"] = Input.is_action_pressed("primary")
		discrete_inputs["secondary"] = Input.is_action_pressed("secondary")
		rpc_send_Discrete_input.rpc_id(get_multiplayer_authority(), discrete_inputs)	
		
	
func react_to_ragdoll():
	
	if is_local_interface:
		recovery_minigame.start()
	
func react_to_ragdoll_recovery():
	
	if is_local_interface:
		recovery_minigame.visible = false
		
func react_early_recovery():
	
	if is_multiplayer_authority() and humanoid.RAGDOLLED:
		humanoid.unragdoll.rpc()


func lunge_at_target(target):
	
	if target != null:
		var disposition = target.global_position - humanoid.global_position
		var distance = disposition.length()
		
		if distance > 3.5:
			pass
			
		elif target.is_in_group("humanoids"):
			humanoid.lunge.rpc(target.get_path())
			
		
@rpc("any_peer", "call_local")
func rpc_send_aim_input(aim_delta):
	
	if str(multiplayer.get_remote_sender_id()) != humanoid.name:
		return
		
	camera.rotate_by_relative_delta(aim_delta)
			
	
@rpc("any_peer", "call_local")
func rpc_send_Continuous_input(inputs):
	
	if str(multiplayer.get_remote_sender_id()) != humanoid.name:
		return
	
	if humanoid.RAGDOLLED:
		return
		
	WASD = inputs['direction']
		
	humanoid.RUNNING = inputs['run']
	
	for key in inputs.keys():
		
		if not cached_inputs.has(key):
			pass
		elif inputs[key] != cached_inputs[key]:
			humanoid.unlagger.reset(multiplayer.get_remote_sender_id())
			
	cache_new_inputs(inputs)
		

@rpc("any_peer", "call_local", "reliable")
func rpc_send_Discrete_input(inputs):
	
	if str(multiplayer.get_remote_sender_id()) != humanoid.name:
		return
		
	if just_pressed('jump', inputs):
		
		if humanoid.ON_FLOOR:
			humanoid.jump.rpc()
		elif humanoid.DOUBLE_JUMP_CHARGES > 0:
			humanoid.double_jump.rpc()
		
	if just_pressed('recover', inputs): 
		recovery_minigame.attempt_early_recovery()
			
	if just_pressed('secondary', inputs):
		
		if not humanoid.RAGDOLLED:
			force.rpc_secondary.rpc()	
			
	elif just_released('secondary', inputs):
		force.rpc_reset.rpc()
		
	if just_pressed('primary', inputs):
		
		if humanoid.RAGDOLLED:
			pass	
			
		elif force.action == force.Action.holding:
			force.rpc_trigger.rpc()
			
		elif force.action == force.Action.cooldown:
			pass	
			
		else:
			force.rpc_primary.rpc()
			lunge_at_target(targeted_object)
		
	cache_new_inputs(inputs)


func just_released(action_key, new_inputs):
	
	var return_val
	
	if not cached_inputs.has(action_key):
		return_val =  false
	elif not cached_inputs[action_key]:
		return_val =  false
	elif not new_inputs[action_key]:
		return_val =  true
		
	return return_val
	
	
func just_pressed(action_key, new_inputs):
	
	var return_val
	
	if not cached_inputs.has(action_key):
		return_val =  false
	elif cached_inputs[action_key]:
		return_val =  false
	elif new_inputs[action_key]:
		return_val =  true
		
	return return_val
	
	
func cache_new_inputs(new_inputs):
	
	for key in new_inputs.keys():
		cached_inputs[key] = new_inputs[key]
		
		
func get_local_humanoid():
	
	if get_parent().is_in_group("humanoids"): #preferred method is just childing this node to humanoid
		return get_parent()
	else:
		return null


func get_local_camera():
	
	var cameras = get_tree().get_nodes_in_group("cameras")
	var local_cameras = cameras.filter(func(node): return node.name == str(multiplayer.get_unique_id()))
	
	if local_cameras.size() > 0:
		return local_cameras[0]
	else:
		return null

