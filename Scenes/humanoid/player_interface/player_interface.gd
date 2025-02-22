extends Node3D

@export var humanoid : Node3D
@export var camera : Node3D
@export var force : Node3D
@export var targeted_object : Node3D

@onready var recovery_bar = $Recovery
@onready var recovery_fill = $Recovery/Fill
@onready var recovery_backdrop = $Recovery/BackDrop
@onready var recovery_target = $Recovery/Target
@onready var recovery_lever = $Recovery/Lever

var recovery_lever_phase = 0.0
var early_recovery_locked = false

var raw_inputs = {}
	
var is_local_interface = false

var cached_inputs = {} #used to determine delta across the network
	
func _ready():
	
	recovery_bar.visible = false
	add_to_group("interfaces")
	humanoid = get_parent()
	force = humanoid.find_child("Force")
	camera = humanoid.find_child("Camera*")
	
	
func _process(delta):	
	
	if camera.shapecast.is_colliding():
		targeted_object = camera.shapecast.get_collider(0)
	
	is_local_interface = str(multiplayer.get_unique_id()) == humanoid.name
	
	if is_local_interface:	
		hmi(delta)
		
		var movement_inputs = {}
		var input_dir = Input.get_vector("left", "right", "forward", "backward")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		movement_inputs['direction'] = direction.rotated(Vector3.UP, camera.rotation.y)
		movement_inputs['run'] = Input.is_action_pressed("run")
		rpc_send_movement_input.rpc(movement_inputs)
		
		var ability_inputs = {}
		ability_inputs['jump'] = Input.is_action_pressed("jump")
		ability_inputs["recover"] = Input.is_action_pressed("recover")
		ability_inputs["primary"] = Input.is_action_pressed("primary")
		ability_inputs["secondary"] = Input.is_action_pressed("secondary")
		rpc_send_ability_input.rpc(ability_inputs)
		
	
func _input(event):
	
	if not is_local_interface:
		return
	
	elif event is InputEventMouseMotion:
		rpc_send_aim_input.rpc(event.relative)
				

func hmi(delta):
	
	recovery_bar.visible = humanoid.RAGDOLLED
	recovery_lever.visible = not early_recovery_locked
	recovery_target.visible = not early_recovery_locked
	
	if not humanoid.RAGDOLLED:
		early_recovery_locked = false
	
	var total_length = recovery_backdrop.size.x
	var total_position = recovery_backdrop.position.x
	recovery_fill.size.x = total_length * humanoid.ragdoll_recovery_progress
	recovery_fill.position.x = total_position * humanoid.ragdoll_recovery_progress
	
	var ragdoll_speed = humanoid.find_child("*lowerBody", true, false).linear_velocity.length()
	recovery_lever_phase += delta * pow(max(humanoid.ragdoll_recovery_default_duration, ragdoll_speed), 0.5)
	
	recovery_lever.position.x = sin(recovery_lever_phase) * total_length / 2.0
	
	if recovery_lever_on_target():
		recovery_target.color = Color('ffc354')
	else:
		recovery_target.color = Color('b98457')

			
func recovery_lever_on_target():
	
	return abs(recovery_lever.position.x) <= recovery_target.size.x / 2.0
	

func lockout_early_recovery():
	
	recovery_target.visible = false
	recovery_lever.visible = false
	early_recovery_locked = true
	
	
func early_recovery():
	
	if humanoid.RAGDOLLED:
		humanoid.unragdoll.rpc()
	

func lunge_at_target(target):
	
	if target != null:
		var disposition = target.global_position - humanoid.global_position
		var distance = disposition.length()
		
		if distance > 3.5:
			pass
			
		elif target.is_in_group("humanoids"):
			#var lunge_velocity = disposition.normalized() * distance * 3.5
			humanoid.lunge.rpc(target.get_path())


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
		
		
@rpc("any_peer", "call_local")
func rpc_send_aim_input(aim_delta):
	
	if str(multiplayer.get_remote_sender_id()) != humanoid.name:
		return
		
	camera.rotate_by_relative_delta(aim_delta)
	humanoid.LOOK_VECTOR = Vector3(sin(camera.rotation.y), camera.rotation.x, cos(camera.rotation.y))
	force.Aim = (humanoid.LOOK_VECTOR * Vector3(-1, 1, -1)).normalized()
	var offset_to_zero = 1.0 - abs(humanoid.LOOK_VECTOR.normalized().dot(Vector3.UP))
	force.base_position = camera.position.lerp(Vector3.ZERO, offset_to_zero * 0.33)
	force.rotation = camera.rotation 
	
	
@rpc("any_peer", "call_local")
func rpc_send_movement_input(inputs):
	
	if str(multiplayer.get_remote_sender_id()) != humanoid.name:
		return
	
	if humanoid.RAGDOLLED:
		return
		
	humanoid.WALK_VECTOR = inputs['direction']
	humanoid.RUNNING = inputs['run']
		
		

@rpc("any_peer", "call_local", "reliable")
func rpc_send_ability_input(inputs):
	
	if str(multiplayer.get_remote_sender_id()) != humanoid.name:
		return
		
	if just_pressed('jump', inputs):
		humanoid.jump.rpc()
		
	if not just_pressed('recover', inputs):
		pass
	elif recovery_lever_on_target():
		early_recovery()
	else:
		lockout_early_recovery()
			
	if just_pressed('secondary', inputs):
		force.rpc_secondary.rpc()	
	elif just_released('secondary', inputs):
		force.rpc_reset.rpc()
		
	if just_pressed('primary', inputs):
		
		if force.action == force.Action.holding:
			force.rpc_trigger.rpc()
	
		elif force.action == force.Action.cooldown:
			pass
		
		else:
			force.rpc_primary.rpc()
			lunge_at_target(targeted_object)
		
	humanoid.REACHING = force.action
		

func just_released(action_key, new_inputs):
	
	var return_val
	
	if not cached_inputs.has(action_key):
		return_val =  false
	elif not cached_inputs[action_key]:
		return_val =  false
	elif not new_inputs[action_key]:
		return_val =  true
		
	cached_inputs[action_key] = new_inputs[action_key]
	return return_val
	
	
func just_pressed(action_key, new_inputs):
	
	var return_val
	
	if not cached_inputs.has(action_key):
		return_val =  false
	elif cached_inputs[action_key]:
		return_val =  false
	elif new_inputs[action_key]:
		return_val =  true
		
	cached_inputs[action_key] = new_inputs[action_key]
	return return_val
