extends Node3D

const camera_prefab = preload("res://Scenes/cameras/FPS_Camera.tscn")
#const force_prefab = preload("res://Scenes/force/force.tscn")

@export var character : Node3D
@export var camera : Node3D
@export var force : Node3D
@export var targeted_object : Node3D

@onready var recovery_bar = $Recovery
@onready var recovery_fill = $Recovery/Fill
@onready var recovery_backdrop = $Recovery/BackDrop
@onready var recovery_target = $Recovery/Target
@onready var recovery_lever = $Recovery/Lever
var lever_phase = 0.0
	
	
func _ready():
	
	recovery_bar.visible = false
	
	
func _process(delta):	
	
	if not character:	
		camera = null
		recovery_bar.visible = false
		
	elif not camera:
		camera = camera_prefab.instantiate()
		character.add_child(camera)
		
	else:
		movement()
		aiming()
		abilities()		
		hmi(delta)


func hmi(delta):
	
	recovery_bar.visible = character.RAGDOLLED
	
	var total_length = recovery_backdrop.size.x
	var total_position = recovery_backdrop.position.x
	recovery_fill.size.x = total_length * character.ragdoll_recovery_progress
	recovery_fill.position.x = total_position * character.ragdoll_recovery_progress
	
	var ragdoll_speed = character.find_child("*lowerBody", true, false).linear_velocity.length()
	lever_phase += delta * pow(max(character.ragdoll_recovery_default_duration, ragdoll_speed), 0.5)
	
	recovery_lever.position.x = sin(lever_phase) * total_length / 2.0
	
	if recovery_lever_on_target():
		recovery_target.color = Color('ffc354')
	else:
		recovery_target.color = Color('b98457')
	
	
func recovery_lever_on_target():
	
	return abs(recovery_lever.position.x) <= recovery_target.size.x / 2.0
	
	
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
	
	camera.HORIZONTAL_SENSITIVITY = 0.002 if character.REACHING else 0.004
	var cam_depth = -1.5 if character.RAGDOLLED else 0.115
	var adjustedOffset = character.LOOK_VECTOR.normalized().rotated(Vector3.UP, PI) * cam_depth
	var adjustedPosition = character.head_position()
	camera.position = adjustedPosition + adjustedOffset	
	var look = Vector3(sin(camera.rotation.y), camera.rotation.x, cos(camera.rotation.y))
	character.LOOK_VECTOR = look
	targeted_object = camera.raycast.get_collider()
	force.Aim = (character.LOOK_VECTOR * Vector3(-1, 1, -1)).normalized()
	var offset_to_zero = 1.0 - abs(character.LOOK_VECTOR.normalized().dot(Vector3.UP))
	force.base_position = camera.position.lerp(Vector3.ZERO, offset_to_zero * 0.33)
	force.rotation = camera.rotation 
	
	
func abilities():
	
	character.REACHING = force.action #enumerations are lined up via integer values
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
		
		if recovery_lever_on_target():
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
			lunge_at_target(targeted_object)
			

func lunge_at_target(targeted_object):
	
	if targeted_object != null:
		var disposition = targeted_object.global_position - character.global_position
		var distance = disposition.length()
		
		if distance > 4:
			pass
			
		elif targeted_object.is_in_group("humanoids"):
			var lunge_velocity = disposition.normalized() * distance * 3.5
			character.lunge.rpc(lunge_velocity)


