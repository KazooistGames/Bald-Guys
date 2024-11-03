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

const MoveState = {
	WALKING = 0,
	FALLING = 1,
	RAGDOLL = 2,
}

@export var MOVE_STATE = MoveState.WALKING
@export var LOOK_VECTOR = Vector3(0,0,0)
@export var WALK_VECTOR = Vector3(0,0,0)
@export var FACING_VECTOR = Vector3(0,0,0)
@export var SPEED_GEARS = Vector2(3.5, 7.0)
@export var JUMP_SPEED = 4
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

const MOUSE_SENSATIVITY = 0.005

var IMPACT_THRESHOLD =  6.5
var ragdoll_cooldown_period_seconds = 0.5
var ragdoll_cooldown_timer_seconds = 0
var ragdoll_recovery_period_seconds = 1
var ragdoll_recovery_timer_seconds = 0

signal ragdolled


func _enter_tree():
	
	add_to_group("humanoids")


func _ready():
	
	#set_multiplayer_authority(str(name).to_int())
	
	if not is_multiplayer_authority(): 
		return
		
	getRandomSkinTone()


func _process(delta):
	
	if MOVE_STATE == MoveState.FALLING:
		
		if is_on_floor():
			land.rpc()
		
	if MOVE_STATE != MoveState.RAGDOLL: #ragdoll cooldown
		ragdoll_cooldown_timer_seconds += delta
		MOVE_STATE = MoveState.WALKING if is_on_floor() else MoveState.FALLING
		
	elif not is_multiplayer_authority():
		return
		
	elif ragdoll_recovered(): 
		unragdoll.rpc()
		
	elif skeleton.ragdoll_is_at_rest(): 
		ragdoll_recovery_timer_seconds += delta
	
	if Main_Trigger: #stop running if necessary
		RUNNING = false
		
	elif WALK_VECTOR.normalized().dot(LOOK_VECTOR.normalized()) > 0.1:
		RUNNING = false
		
	elif velocity == Vector3.ZERO:
		RUNNING = false
		
	TOPSPEED = SPEED_GEARS.y if RUNNING else SPEED_GEARS.x
	TOPSPEED_MOD = 0.9 if Main_Trigger else 1.0
	animation.walkAnimBlendScalar = TOPSPEED
	animation.walkAnimPlaybackScalar = 1.5 if RUNNING else 1.8
	animation.WALK_STATE = animation.WalkState.RUNNING if RUNNING else animation.WalkState.WALKING
	
	match MOVE_STATE:
		
		MoveState.FALLING:
			IMPACT_THRESHOLD = 7.0
			animation.updateFalling(velocity)
			skeleton.processSkeletonRotation(LOOK_VECTOR, 0.3, 1.0)
			
		MoveState.WALKING:
			IMPACT_THRESHOLD = 5.0
			animation.updateWalking(TOPSPEED, get_real_velocity(), is_back_pedaling())
			
			if(WALK_VECTOR):
				skeleton.processSkeletonRotation(LOOK_VECTOR, 0.7, 1.0)
				
			else:
				skeleton.processSkeletonRotation(LOOK_VECTOR, 0.5, 1.0)
				
	FACING_VECTOR = Vector3(sin(skeleton.rotation.y), skeleton.rotation.x, cos(skeleton.rotation.y))


func _physics_process(delta):
	
	var test_move_collision : KinematicCollision3D = KinematicCollision3D.new()

	if not is_multiplayer_authority() : 
		move_and_slide()
		
	elif not test_move(transform, velocity * delta, test_move_collision):
		move_and_slide()
		
	elif not handle_collision(delta, test_move_collision):
		move_and_slide()
		
	WALK_VECTOR = WALK_VECTOR.normalized()
	var translational_velocity = Vector2(velocity.x, velocity.z)
	var WALK_VECTOR_2 = Vector2(WALK_VECTOR.x, WALK_VECTOR.z)
	
	match MOVE_STATE:
		
		MoveState.FALLING:
			
			if velocity.y <= 2.75:
				FLOATING = false
				
			if FLOATING:
				velocity.y -= gravity * delta / 3
				
			else:
				velocity.y -= gravity * delta
				
			var velocityStep = acceleration() * delta
			
			if WALK_VECTOR:
				translational_velocity.x += WALK_VECTOR.x * velocityStep/2
				translational_velocity.y += WALK_VECTOR.z * velocityStep/2
				
			translational_velocity = translational_velocity.move_toward(Vector2.ZERO, 2 * delta)
			skeleton.processFallOrientation(delta, LOOK_VECTOR, velocity)
			
			var jumpDeltaScale = animation.get("parameters/Jump/blend_position")
			collider.shape.height = clamp(lerp(1.5, 1.0, jumpDeltaScale ), 1.0, 1.5)
			collider.position.y = clamp(lerp(0.75, 1.0, jumpDeltaScale ), 0.75, 1.0)
			
		MoveState.WALKING:
			var velocityStep = acceleration() * 2 * delta
			var speed_target = TOPSPEED * TOPSPEED_MOD
			
			if WALK_VECTOR:
				translational_velocity = translational_velocity.move_toward(WALK_VECTOR_2 * speed_target, velocityStep)
				skeleton.processWalkOrientation(delta , LOOK_VECTOR, lerp(velocity, WALK_VECTOR, 0.5 ) )
				
			else:
				translational_velocity = translational_velocity.move_toward(Vector2.ZERO, velocityStep)
				skeleton.processIdleOrientation(delta, LOOK_VECTOR)
				
			var scalar = 2
			collider.shape.height = move_toward(collider.shape.height, 1.5, delta * scalar)
			collider.position.y = move_toward(collider.position.y, 0.75, delta * scalar)
			
		MoveState.RAGDOLL:
			translational_velocity = Vector2.ZERO
			skeleton.processRagdollOrientation(delta)
		
	velocity.x = translational_velocity.x
	velocity.z = translational_velocity.y
	
	skeleton.processReach(LOOK_VECTOR, Main_Trigger)
	rotation.y = fmod(rotation.y, 2*PI)
	
	if is_multiplayer_authority():
		AUTHORITY_POSITION = position
	elif position.distance_to(AUTHORITY_POSITION) > 1.5:
		position = AUTHORITY_POSITION
	else:
		position = position.lerp(AUTHORITY_POSITION, 0.05)

func is_back_pedaling():
	
	var walkVec2 = Vector2(WALK_VECTOR.x, WALK_VECTOR.z).normalized()
	var lookVec2 = Vector2(LOOK_VECTOR.x, LOOK_VECTOR.z).normalized()
	return walkVec2.dot(lookVec2 ) > 0


func acceleration():
	
	var absolute = 20
	var translationalSpeed = Vector2(velocity.x, velocity.z).length()
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
	
	
func handle_collision(delta, collision):

	var relativeVelocity = get_real_velocity() - collision.get_collider_velocity()
	var otherCollider = collision.get_collider() as Node3D
	var directionalModifier = 1.0 - collision.get_normal().dot(Vector3.UP)/2
	var normal = collision.get_normal()
	var impact = -relativeVelocity.dot(normal) * directionalModifier
			
	if otherCollider.is_in_group("humanoids"):
		
			if otherCollider.check_if_impact_meets_threshold(impact):
				otherCollider.ragdoll_recovery_period_seconds = impact / IMPACT_THRESHOLD
				otherCollider.ragdoll.rpc()
				
	elif not otherCollider.is_in_group("floor") and MOVE_STATE == MoveState.FALLING:
		
		var projection_scale = abs(LOOK_VECTOR.normalized().dot(normal))			
		
		var check1 = projection_scale <= 3.0/4.0	
		var check2 = impact > 3.0
		
		if check1 and check2 and not is_on_floor():
			var bounced = relativeVelocity.bounce(normal)
			var new_velocity = Vector3(bounced.x, velocity.y, bounced.z)
			new_velocity.y += JUMP_SPEED * 2.0 / 3.0
			wall_bounce.rpc(new_velocity)
			return true

	if  check_if_impact_meets_threshold(impact): 
		ragdoll_recovery_period_seconds = impact / IMPACT_THRESHOLD
		ragdoll.rpc()
		return true

	else:
		return false


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
		RUNNING = false
		ragdolled.emit()
		skeleton.ragdoll_start()
		ragdoll_recovery_timer_seconds = 0
		animation.active = false
		collider.disabled = true
		MOVE_STATE = MoveState.RAGDOLL
		#var propertyPath = "Skeleton3D/Ragdoll/Physical Bone "
		#toggle_ragdoll_sync(1)
		
		
@rpc("call_local", "any_peer")
func unragdoll():
	
	if(MOVE_STATE == MoveState.RAGDOLL):
		ragdoll_cooldown_timer_seconds = 0
		position = skeleton.ragdoll_position()
		skeleton.ragdoll_stop()
		animation.active = true
		collider.disabled = false
		MOVE_STATE = MoveState.FALLING
		#toggle_ragdoll_sync(0)	


@rpc("call_local")
func wall_bounce(new_velocity):
	velocity = new_velocity
	FLOATING = false


@rpc("call_local")
func jump():
	
	if is_on_floor():
		velocity.y += JUMP_SPEED
		
		
@rpc("call_local")
func land():
	
	if is_on_floor():
		velocity = velocity.move_toward(Vector3.ZERO, 2)
		
