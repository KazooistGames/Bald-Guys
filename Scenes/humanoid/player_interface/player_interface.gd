extends Node

@export var WASD = Vector2.ZERO
@export var look = Vector3.ZERO

@onready var recovery_minigame = $RecoveryMinigame

var humanoid : Node3D
var camera : Node3D
var force : Node3D
var targeted_object : Node3D

var is_local_interface = false #input hardware is connected to this node
var cached_inputs = {} #used to determine delta across the network
	
var whitelist : Array[String] =  [
	"transform",
	"linear_velocity",
	"WALK_VECTOR", 
	"LOOK_VECTOR", 
	"RUNNING", 
	"ON_FLOOR",
	#"RAGDOLLED", 
	"ragdoll_recovery_progress"
]

var blacklist : Array[String] = [
	'RAGDOLLED', 
]	

func _ready():

	add_to_group("interfaces")
	humanoid = get_parent()
	force = humanoid.find_child("Force")
	camera = humanoid.find_child("Camera*")
	humanoid.ragdolled.connect(handle_ragdoll)
	humanoid.unragdolled.connect(handle_ragdoll_recovery)
	recovery_minigame.succeeded.connect(handle_early_recovery)
	

func _process(_delta):
	
	var ragdoll_speed = humanoid.find_child("*lowerBody", true, false).linear_velocity.length()
	recovery_minigame.difficulty = pow(max(1.0, ragdoll_speed), 0.5)
	recovery_minigame.progress = humanoid.ragdoll_recovery_progress
	
	
func _physics_process(_delta):	

	var direction = (Basis.IDENTITY * Vector3(WASD.x, 0, WASD.y)).normalized()
	humanoid.WALK_VECTOR = direction.rotated(Vector3.UP, camera.rotation.y)
	humanoid.REACHING = force.action
	humanoid.LOOK_VECTOR = Vector3(sin(camera.rotation.y), camera.rotation.x, cos(camera.rotation.y))
	force.Aim = (humanoid.LOOK_VECTOR * Vector3(-1, 1, -1)).normalized()
	var offset_to_zero = 1.0 - abs(humanoid.LOOK_VECTOR.normalized().dot(Vector3.UP))
	force.base_position = humanoid.head_position().lerp(Vector3.ZERO, offset_to_zero / 3.0)
	force.rotation = camera.rotation 
	
	if camera.shapecast.is_colliding():
		targeted_object = camera.shapecast.get_collider(0)
		
	if not multiplayer.has_multiplayer_peer():
		return
		
	is_local_interface = str(multiplayer.get_unique_id()) == humanoid.name

	if is_local_interface:	
		camera.current = true	
		var continuous_inputs = {}
		continuous_inputs['look'] = look
		continuous_inputs['wasd'] = Input.get_vector("left", "right", "forward", "backward")
		continuous_inputs['run'] = not Input.is_action_pressed("run")
		var timestamp = Time.get_unix_time_from_system()
		rpc_update_Continuous_inputs.rpc(continuous_inputs, timestamp)
		WASD = continuous_inputs['wasd']
		humanoid.RUNNING = continuous_inputs['run']
		
	else:
		camera.rotation = look
			
	
func _input(event):
	
	if not is_local_interface:
		return
	
	elif event is InputEventMouseMotion:
		look = camera.rotate_by_relative_delta(event.relative)
			
	else:
		var discrete_inputs = {}
		discrete_inputs['jump'] = Input.is_action_pressed("jump")
		discrete_inputs["primary"] = Input.is_action_pressed("primary")
		discrete_inputs["secondary"] = Input.is_action_pressed("secondary")
		var timestamp = Time.get_unix_time_from_system()
		
		if not Input.is_action_pressed("recover") or recovery_minigame.locked:
			discrete_inputs["recover"] = false
		elif recovery_minigame.lever_on_target(timestamp, recovery_minigame.difficulty):
			discrete_inputs["recover"] = true
		else:
			recovery_minigame.early_fail()
		
		if detected_input_change(discrete_inputs) or cached_inputs.size() == 0:
			rpc_update_Discrete_inputs.rpc_id(get_multiplayer_authority(), discrete_inputs, timestamp)	
			
		cache_new_inputs(discrete_inputs)
	
	
	
@rpc("any_peer", "call_local", "unreliable_ordered")
func rpc_update_Continuous_inputs(inputs, timestamp):
	
	if not is_multiplayer_authority():
		return
		
	var action_committed = false
	var rollback_lag = Time.get_unix_time_from_system() - timestamp
	#rollback_lag = 0.15
	
	if just_changed('wasd', inputs):
		action_committed = true
		
	if action_committed: #ROLLBACK	

		humanoid.rollback(rollback_lag, [], whitelist)	
		force.rollback(rollback_lag)
		
	
	look = inputs['look']	
	humanoid.RUNNING = inputs['run']
	WASD = inputs['wasd']
	var direction = (Basis.IDENTITY * Vector3(WASD.x, 0, WASD.y)).normalized()
	humanoid.WALK_VECTOR =  direction.rotated(Vector3.UP, camera.rotation.y)
		
	if action_committed:
		perform_player_prediction(rollback_lag)

	cache_new_inputs(inputs)
		

@rpc("any_peer", "call_local", "reliable")
func rpc_update_Discrete_inputs(inputs : Dictionary, timestamp):
	
	#var sender_id = multiplayer.get_remote_sender_id()
	
	if not is_multiplayer_authority():
		return
		
	var rollback_lag = Time.get_unix_time_from_system() - timestamp	
	#rollback_lag = .15
	var action_committed = false

	for key in inputs.keys():
		
		if just_pressed(key, inputs):
			action_committed = true
		
	if action_committed: #ROLLBACK		
		
		humanoid.rollback(rollback_lag, blacklist, [])	
		force.rollback(rollback_lag)
	
	if just_pressed('jump', inputs):	
	
		#var jump_available = humanoid.ON_FLOOR or humanoid.DOUBLE_JUMP_CHARGES > 0

		if humanoid.ON_FLOOR:
			humanoid.jump.rpc()
		elif humanoid.DOUBLE_JUMP_CHARGES > 0:
			humanoid.double_jump.rpc()
	
	if just_pressed('recover', inputs): 
		
		recovery_minigame.attempt_early_recovery(timestamp)
			
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

	elif just_released('primary', inputs):	
		force.rpc_release.rpc()
		
	if action_committed: #PREDICT
		perform_player_prediction(rollback_lag)
		
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
	
	
func just_changed(action_key, new_inputs):
	
	if not cached_inputs.has(action_key):
		return false
	else:
		return cached_inputs[action_key] != new_inputs[action_key]
	
	
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
	
	
func detected_input_change(inputs) -> bool:
	
	for key in inputs.keys():
		
		if just_pressed(key, inputs):
			return true
			
		if just_released(key, inputs):
			return true
			
	return false
		
	
func handle_ragdoll(_humanoid):
	
	if is_local_interface:
		recovery_minigame.start_game()
	
	
func handle_ragdoll_recovery():
	
	if is_local_interface:
		recovery_minigame.visible = false


func handle_early_recovery():
	
	if is_multiplayer_authority() and humanoid.RAGDOLLED:
		humanoid.ragdoll_recovery_progress = 1.0


func perform_player_prediction(rollback_lag):
	
	var lag : float = rollback_lag
	var step_size : float
	
	while lag > 0:
		step_size = min(get_physics_process_delta_time(), lag)
		lag -= step_size
		humanoid.predict(step_size)
		humanoid.rectifier.update_cache(lag)	
		force.predict(step_size)	
		force.rectifier.update_cache(lag)

