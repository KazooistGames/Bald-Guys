extends RigidBody3D

const floor_normal = Vector3(0, 1, 0)
const floor_angle = PI/3.0

@export var SKIN_COLOR : Color:
	
	get:
		return SKIN_COLOR
		
	set(value):
		SKIN_COLOR = value
		var model = $Skeleton3D/Ragdoll/Cube
		var material = model.get_surface_override_material(0)
		material.albedo_color = value
		model.set_surface_override_material(0, material)
	
@export var RAGDOLLED = false
@export var ON_FLOOR = true
@export var REACHING = false

@export var LOOK_VECTOR = Vector3(0,0,0)
@export var WALK_VECTOR = Vector3(0,0,0)
@export var FACING_VECTOR = Vector3(0,0,0)
@export var SPEED_GEARS = Vector2(3.5, 7.0)
@export var JUMP_SPEED = 4.5
@export var RUNNING = false
@export var FLOATING = false

@export var AUTHORITY_POSITION = Vector3.ZERO

@onready var skeleton = $Skeleton3D
@onready var animation = $AnimationTree
@onready var collider = $CollisionShape3D
@onready var synchronizer = $MultiplayerSynchronizer


var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var TOPSPEED = 0
var TOPSPEED_MOD = 1

var IMPACT_THRESHOLD =  6.5
var ragdoll_cooldown_period_seconds = 0.5
var ragdoll_cooldown_timer_seconds = 0
var ragdoll_recovery_period_seconds = 1
var ragdoll_recovery_timer_seconds = 0



signal ragdolled


func _enter_tree():
	
	add_to_group("humanoids")


func _ready():
	
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 5
	
	if is_multiplayer_authority(): 
		getRandomSkinTone()
		

func _process(_delta):
			
	if not RAGDOLLED: #ragdoll cooldown
		pass
		
	elif not is_multiplayer_authority():
		return
		
	elif get_ragdoll_recovered(): 
		unragdoll.rpc()
	
	if REACHING: #stop running if necessary
		RUNNING = false
		
	elif WALK_VECTOR.normalized().dot(LOOK_VECTOR.normalized()) > 0.1:
		RUNNING = false
		
	elif WALK_VECTOR == Vector3.ZERO:
		RUNNING = false	

	TOPSPEED_MOD = 0.9 if REACHING else 1.0
	animation.walkAnimBlendScalar = TOPSPEED
	animation.walkAnimPlaybackScalar = 1.5 if RUNNING else 1.8
	animation.WALK_STATE = animation.WalkState.RUNNING if RUNNING else animation.WalkState.WALKING
	
	if RAGDOLLED:
		pass
		
	elif ON_FLOOR:
		TOPSPEED = SPEED_GEARS.y if RUNNING else SPEED_GEARS.x
		IMPACT_THRESHOLD = 4.5 * mass
		animation.updateWalking(TOPSPEED, linear_velocity, is_back_pedaling())
		
		if(WALK_VECTOR):
			skeleton.processSkeletonRotation(LOOK_VECTOR, 0.7, 1.0)
			
		else:
			skeleton.processSkeletonRotation(LOOK_VECTOR, 0.5, 1.0)
			
	else:
		TOPSPEED = SPEED_GEARS.y
		IMPACT_THRESHOLD = 6.0 * mass
		animation.updateFalling(linear_velocity)
		skeleton.processSkeletonRotation(LOOK_VECTOR, 0.3, 1.0)
			
	FACING_VECTOR = Vector3(sin(skeleton.rotation.y), skeleton.rotation.x, cos(skeleton.rotation.y))
	skeleton.processReach(LOOK_VECTOR, REACHING)
	

func _integrate_forces(state):
	
	WALK_VECTOR = WALK_VECTOR.normalized()
	
	if is_multiplayer_authority():
		AUTHORITY_POSITION = state.transform.origin	
		
	elif position.distance_to(AUTHORITY_POSITION) > 1.0:
		state.transform.origin = state.transform.origin.lerp(AUTHORITY_POSITION, 0.25)
		
	else:
		state.transform.origin = state.transform.origin.lerp(AUTHORITY_POSITION, 0.05)

	var contact_count = state.get_contact_count()
	
	var ON_FLOOR_buffer = false
	
	for index in range(contact_count):

		var normal = state.get_contact_local_normal(index)
		#var otherCollider : Node3D = state.get_contact_collider_object(index)

		if normal.angle_to(floor_normal) <= floor_angle:		
			ON_FLOOR_buffer = true

		var directionalModifier = pow((1.0 - normal.dot(Vector3.UP)/2), 2)
		var impact = state.get_contact_impulse(index).length() * directionalModifier

		if not is_multiplayer_authority():
			pass
			
		elif is_multiplayer_authority() and impact >= IMPACT_THRESHOLD: 
			ragdoll_recovery_period_seconds = impact / IMPACT_THRESHOLD
			ragdoll.rpc()

		elif not ON_FLOOR_buffer and not ON_FLOOR:
			var check1 = abs(LOOK_VECTOR.normalized().dot(normal)) <= 1.0/2.0	
			var check2 = impact > IMPACT_THRESHOLD/2
			var check3 = abs(normal.dot(floor_normal)) <= 0.5

			if check1 and check2 and check3:
				state.apply_central_impulse(state.get_contact_impulse(index))
				state.apply_central_impulse(Vector3.UP * JUMP_SPEED/2 * mass)
				FLOATING = false
			
	var translational_velocity = Vector3(linear_velocity.x, 0, linear_velocity.z)
		
	if is_multiplayer_authority() and not ON_FLOOR and ON_FLOOR_buffer and translational_velocity.length() > 0.5:
		land.rpc()
		
	ON_FLOOR = ON_FLOOR_buffer
		
	var speed_target = TOPSPEED * TOPSPEED_MOD
	var impulse = Vector3.ZERO
		
	if RAGDOLLED:
		pass
	
	elif ON_FLOOR:
		
		if WALK_VECTOR == Vector3.ZERO:			
			impulse = -translational_velocity * get_acceleration() * mass

		elif translational_velocity.length() < speed_target:
			impulse = WALK_VECTOR * get_acceleration() * 2 * mass

		else:
			var removal_factor = WALK_VECTOR.project(translational_velocity).normalized()
			impulse = (WALK_VECTOR - removal_factor).normalized() * get_acceleration() * 2 * mass

	else:
				
		if linear_velocity.y <= 2.75:
			FLOATING = false
			
		if FLOATING:
			gravity_scale = 1.0/3.0
			
		else:
			gravity_scale = 1

		if WALK_VECTOR:
			impulse = WALK_VECTOR * get_acceleration()/2 * mass
			
	apply_central_force(impulse)
	
	if translational_velocity.length() > speed_target:
		impulse = -translational_velocity * get_acceleration() * mass
		apply_central_force(impulse)
	

func _physics_process(delta):
	
	if not RAGDOLLED:
		ragdoll_cooldown_timer_seconds += delta
		
	elif skeleton.ragdoll_is_at_rest():
		ragdoll_recovery_timer_seconds += delta
				
	if RAGDOLLED:
		skeleton.processRagdollOrientation(delta)
		
	elif ON_FLOOR:
		
		if WALK_VECTOR == Vector3.ZERO:		
			skeleton.processIdleOrientation(delta, LOOK_VECTOR)

		else:
			skeleton.processWalkOrientation(delta , LOOK_VECTOR, lerp(linear_velocity, WALK_VECTOR, 0.5 ) )
		
		var scalar = 2
		collider.shape.height = move_toward(collider.shape.height, 1.5, delta * scalar)
		collider.position.y = move_toward(collider.position.y, 0.75, delta * scalar)
		
	else:
		skeleton.processFallOrientation(delta, LOOK_VECTOR, linear_velocity)		
		var jumpDeltaScale = animation.get("parameters/Jump/blend_position")
		collider.shape.height = clamp(lerp(1.5, 1.0, jumpDeltaScale ), 1.0, 1.5)
		collider.position.y = clamp(lerp(0.75, 1.0, jumpDeltaScale ), 0.75, 1.0)

	rotation.y = fmod(rotation.y, 2*PI)
	
	
func is_back_pedaling():
	
	var walkVec2 = Vector2(WALK_VECTOR.x, WALK_VECTOR.z).normalized()
	var lookVec2 = Vector2(LOOK_VECTOR.x, LOOK_VECTOR.z).normalized()
	return walkVec2.dot(lookVec2 ) > 0


func get_acceleration():
	
	var absolute = 20
	var translationalSpeed = Vector2(linear_velocity.x, linear_velocity.z).length()
	var relative = pow(1 / max(translationalSpeed, 1 ), 0.5)
	var return_val = absolute * relative
	return return_val


func getRandomSkinTone():
	
	var rng = RandomNumberGenerator.new()
	var colorBase = rng.randf_range(40.0, 220.0 ) / 255
	var redShift = rng.randf_range(20,30 ) / 255
	var blueShift = rng.randf_range(0, redShift ) / 255
	SKIN_COLOR = Color(colorBase + redShift, colorBase, colorBase-blueShift )


func head_position():
	
	var headPosition = skeleton.head_position()
	var adjustedPosition = headPosition.rotated(Vector3.UP, skeleton.rotation.y ) 
	return adjustedPosition
	

func get_ragdoll_ready():
	
	return ragdoll_cooldown_timer_seconds > ragdoll_cooldown_period_seconds
	
	
func get_ragdoll_recovered():
	
	return ragdoll_recovery_timer_seconds > ragdoll_recovery_period_seconds


@rpc("call_local")
func ragdoll():
	
	if not RAGDOLLED:
		RUNNING = false
		ragdolled.emit()
		skeleton.ragdoll_start()
		ragdoll_recovery_timer_seconds = 0
		animation.active = false
		collider.disabled = true
		RAGDOLLED = true
		freeze = true
		
		
@rpc("call_local")
func unragdoll():
	
	if RAGDOLLED:
		ragdoll_cooldown_timer_seconds = 0
		position = skeleton.ragdoll_position()
		skeleton.ragdoll_stop()
		animation.active = true
		collider.disabled = false
		RAGDOLLED = false
		freeze = false


@rpc("call_local")
func jump():
	
	if ON_FLOOR:
		apply_central_impulse(Vector3.UP * mass * JUMP_SPEED)
		
		
@rpc("call_local")
func land():
	
	if ON_FLOOR:
		var translational_velocity = Vector3(linear_velocity.x, 0, linear_velocity.z)
		var retardation_vector = -translational_velocity.normalized()
		var impulse = retardation_vector * mass * 2
		apply_central_impulse(impulse)

	
