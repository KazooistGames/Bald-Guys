extends CharacterBody3D

@export var SKIN_COLOR : Color:
	get:
		return SKIN_COLOR
	set(value):
		SKIN_COLOR = value
		var model = $Skeleton3D/Ragdoll/Cube
		var material = model.get_surface_override_material(0)
		material.albedo_color = value
		model.set_surface_override_material(0, material)
		
@export var Main_Trigger = false

@export var MOVE_STATE = MoveState.WALKING
@export var LOOK_VECTOR = Vector3(0,0,0)
@export var WALK_VECTOR = Vector3(0,0,0)
@export var SPEED_GEARS = Vector2(3.0, 6.0)
@export var JUMP_SPEED = 4.5
@export var RUNNING = false

@onready var skeleton = $Skeleton3D
@onready var animation = $AnimationTree
@onready var collider = $CollisionShape3D
@onready var synchronizer = $MultiplayerSynchronizer

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var TOPSPEED = 0
var TOPSPEED_MOD = 1

const MOUSE_SENSATIVITY = 0.005

const MoveState = {
	WALKING = 0,
	FALLING = 1,
	RAGDOLL = 2,
}

var IMPACT_THRESHOLD =  6.0
var ragdoll_cooldown_period_seconds = 1
var ragdoll_cooldown_timer_seconds = 0
var ragdoll_recovery_period_seconds = 1
var ragdoll_recovery_timer_seconds = 0

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	add_to_group("humanoids")

func _ready():
	if not is_multiplayer_authority(): return
	getRandomSkinTone()

func _process(delta):
	if MOVE_STATE == MoveState.RAGDOLL:
		if not is_multiplayer_authority(): return
		elif ragdoll_recovered(): unragdoll.rpc()
		elif skeleton.ragdoll_is_at_rest(): ragdoll_recovery_timer_seconds += delta
	else:
		ragdoll_cooldown_timer_seconds += delta
		MOVE_STATE = MoveState.WALKING if is_on_floor() else MoveState.FALLING
	if Main_Trigger or WALK_VECTOR.normalized().dot(LOOK_VECTOR.normalized()) > 0.1:
		RUNNING = false
	TOPSPEED = SPEED_GEARS.y if RUNNING else SPEED_GEARS.x
	TOPSPEED_MOD = 0.75 if Main_Trigger else 1.0
	animation.walkAnimBlendScalar = TOPSPEED
	animation.walkAnimPlaybackScalar = 1.5 if RUNNING else 1.8
	animation.WALK_STATE = animation.WalkState.RUNNING if RUNNING else animation.WalkState.WALKING
	match MOVE_STATE:
		MoveState.FALLING:
			IMPACT_THRESHOLD = 10
			animation.updateFalling(velocity)
			skeleton.processSkeletonRotation(LOOK_VECTOR, 0.3, 1.0)
		MoveState.WALKING:
			IMPACT_THRESHOLD = 4.5
			animation.updateWalking(TOPSPEED, get_real_velocity(), is_back_pedaling())
			skeleton.processSkeletonRotation(LOOK_VECTOR, 0.7, 1.0)

func _physics_process(delta):
	physics_collisions(delta)
	WALK_VECTOR = WALK_VECTOR.normalized()
	match MOVE_STATE:
		MoveState.FALLING:
			physics_falling(delta)
		MoveState.WALKING:
			physics_walking(delta)
		MoveState.RAGDOLL:
			physics_ragdoll(delta)
	if Main_Trigger:
		skeleton.processReach(LOOK_VECTOR)

##### PHYSICS UPDATES FOR DIFFERENT MOVEMENT TYPES #####
func physics_ragdoll(delta):
	velocity = Vector3.ZERO
	skeleton.processRagdollOrientation(delta)
	
func physics_falling(delta):
	velocity.y -= gravity * delta
	var velocityStep = acceleration()/3 * delta
	if WALK_VECTOR:
		velocity.x += WALK_VECTOR.x * velocityStep
		velocity.z += WALK_VECTOR.z * velocityStep
	skeleton.processFallOrientation(delta, LOOK_VECTOR, WALK_VECTOR)

func physics_walking(delta):
	var velocityStep = acceleration() * delta
	var speed_target = TOPSPEED * TOPSPEED_MOD
	if WALK_VECTOR:
		velocity.x = lerp(velocity.x, WALK_VECTOR.x * speed_target, velocityStep)
		velocity.z = lerp(velocity.z, WALK_VECTOR.z * speed_target, velocityStep)
		skeleton.processWalkOrientation(delta, LOOK_VECTOR, WALK_VECTOR if is_on_floor() else Vector3.ZERO)
	else:
		velocity.x = lerp(velocity.x, 0.0, velocityStep)
		velocity.z = lerp(velocity.z, 0.0, velocityStep)
		skeleton.processIdleOrientation(delta, LOOK_VECTOR)

func is_back_pedaling():
	var walkVec2 = Vector2(WALK_VECTOR.x, WALK_VECTOR.z).normalized()
	var lookVec2 = Vector2(LOOK_VECTOR.x, LOOK_VECTOR.z).normalized()
	return walkVec2.dot(lookVec2) > 0

func acceleration():
	var absolute = 8 if RUNNING else 16
	var translationalSpeed = Vector2(velocity.x, velocity.z).length()
	var relative = pow(1/max(translationalSpeed, 1), 0.5)
	return absolute * relative

func getRandomSkinTone():
	var rng = RandomNumberGenerator.new()
	var colorBase = rng.randf_range(40.0, 200.0)/255
	var redShift = rng.randf_range(20,30)/255
	SKIN_COLOR = Color(colorBase + redShift, colorBase, colorBase)

func head_position():
	var headPosition = skeleton.head_position()
	var adjustedPosition = headPosition.rotated(Vector3.UP, skeleton.rotation.y) 
	return adjustedPosition
	
func physics_collisions(delta):
	if not is_multiplayer_authority(): move_and_slide()
	elif test_move(transform, velocity * delta) && ragdoll_is_ready():
		handle_collision(delta)
	else:
		move_and_slide()

func handle_collision(delta):
	var collision = move_and_collide(velocity * delta)
	if collision:
		var relativeVelocity = collision.get_collider_velocity() - get_real_velocity()
		var otherCollider = collision.get_collider()
		var layer = otherCollider.get_collision_layer()
		var impact = relativeVelocity.dot(collision.get_normal())
		match layer:
			2:
				impact = sqrt(pow(relativeVelocity.dot(collision.get_normal()), 2)/2)
				if otherCollider.check_if_impact_meets_threshold(impact):
					otherCollider.ragdoll_recovery_period_seconds = impact / IMPACT_THRESHOLD
					otherCollider.ragdoll.rpc()
			4:
				pass
		if  check_if_impact_meets_threshold(impact): 
			ragdoll_recovery_period_seconds = impact / IMPACT_THRESHOLD
			ragdoll.rpc()
		else:
			move_and_slide()

func check_if_impact_meets_threshold(impact):
	if impact > IMPACT_THRESHOLD:
		return true
	else:
		return false

func ragdoll_is_ready():
	return ragdoll_cooldown_timer_seconds > ragdoll_cooldown_period_seconds
	
func ragdoll_recovered():
	return ragdoll_recovery_timer_seconds > ragdoll_recovery_period_seconds
	
func force_push():
	pass
	
func toggle_ragdoll_sync(sync_mode):
		var propertyPath = "Skeleton3D/Ragdoll/Physical Bone "
		synchronizer.replication_config.property_set_replication_mode(propertyPath+"lowerBody:linear_velocity", sync_mode)
		synchronizer.replication_config.property_set_replication_mode(propertyPath+"lowerBody:angular_velocity", sync_mode)
		synchronizer.replication_config.property_set_replication_mode(propertyPath+"upperBody:linear_velocity", sync_mode)
		synchronizer.replication_config.property_set_replication_mode(propertyPath+"upperBody:angular_velocity", sync_mode)

@rpc("call_local", "any_peer")
func ragdoll():
	if(MOVE_STATE != MoveState.RAGDOLL && ragdoll_is_ready()):
		skeleton.RAGDOLLED = true
		ragdoll_recovery_timer_seconds = 0
		animation.active = false
		collider.disabled = true
		MOVE_STATE = MoveState.RAGDOLL
		var propertyPath = "Skeleton3D/Ragdoll/Physical Bone "
		toggle_ragdoll_sync(1)
		
@rpc("call_local", "any_peer")
func unragdoll():
	if(MOVE_STATE == MoveState.RAGDOLL):
		ragdoll_cooldown_timer_seconds = 0
		var skeletonPosition = skeleton.ragdoll_position()
		position = skeletonPosition
		skeleton.RAGDOLLED = false
		animation.active = true
		collider.disabled = false
		MOVE_STATE = MoveState.FALLING
		toggle_ragdoll_sync(0)

@rpc("call_local")
func jump():
	if is_on_floor() and not Main_Trigger:
		velocity.y = JUMP_SPEED
