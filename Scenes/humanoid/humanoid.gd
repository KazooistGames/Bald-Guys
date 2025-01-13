extends RigidBody3D

const floor_normal = Vector3(0, 1, 0)
const floor_angle = PI/4.0

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
@export var REACHING = 0

@export var LOOK_VECTOR = Vector3(0,0,0)
@export var WALK_VECTOR = Vector3(0,0,0)
@export var FACING_VECTOR = Vector3(0,0,0)
@export var SPEED_GEARS = Vector2(3.5, 7.0)
@export var JUMP_SPEED = 5.0
@export var RUNNING = false
@export var DOUBLE_JUMP_CHARGES = 1

@export var AUTHORITY_POSITION = Vector3.ZERO

@onready var skeleton = $Skeleton3D
@onready var animation = $AnimationTree
@onready var collider = $CollisionShape3D
@onready var collider2 = $CollisionShape3D2
@onready var collider3 = $CollisionShape3D3
@onready var synchronizer = $MultiplayerSynchronizer
@onready var floorcast = $FloorCast3D

var TOPSPEED = 0
var TOPSPEED_MOD = 1

var IMPACT_THRESHOLD =  6.5
var ragdoll_cooldown_period_seconds = 0.5
var ragdoll_cooldown_timer_seconds = 0
var ragdoll_recovery_period_seconds = 1
var ragdoll_recovery_timer_seconds = 0

signal ragdolled

@onready var impactFX = $ImpactAudio
@onready var jumpFX = $JumpAudio

var coyote_timer = 0.0
var coyote_duration = 0.1
var reverse_coyote_timer = 0.0

var floor_velocity = Vector3(0,0,0)
var walk_velocity = Vector3.ZERO

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
	elif get_ragdoll_recovered() and is_multiplayer_authority(): 
		unragdoll.rpc()
		
	if WALK_VECTOR.normalized().dot(LOOK_VECTOR.normalized()) > 0.1:
		RUNNING = false	
	elif WALK_VECTOR == Vector3.ZERO:
		RUNNING = false	

	animation.walkAnimBlendScalar = TOPSPEED
	animation.walkAnimPlaybackScalar = 1.5 if RUNNING else 1.8
	animation.WALK_STATE = animation.WalkState.RUNNING if RUNNING else animation.WalkState.WALKING
	
	IMPACT_THRESHOLD = 6.0 * mass
	
	if RAGDOLLED:
		pass
		
	elif ON_FLOOR:
		TOPSPEED = SPEED_GEARS.y if RUNNING else SPEED_GEARS.x
		animation.updateWalking(TOPSPEED, walk_velocity, is_back_pedaling())
		
		if(WALK_VECTOR):
			skeleton.processSkeletonRotation(LOOK_VECTOR, 0.7, 1.0)		
		else:
			skeleton.processSkeletonRotation(LOOK_VECTOR, 0.5, 1.0)
			
	else:
		animation.updateFalling(linear_velocity)
		skeleton.processSkeletonRotation(LOOK_VECTOR, 0.3, 1.0)
			
	FACING_VECTOR = Vector3(sin(skeleton.rotation.y), skeleton.rotation.x, cos(skeleton.rotation.y))
	skeleton.processReach(LOOK_VECTOR)
	skeleton.Reaching = REACHING
	

func _integrate_forces(state):	
	
	if not floorcast.is_colliding():
		pass	
		
	elif state.transform.origin.distance_to(floorcast.get_collision_point()) <= floorcast.target_position.length():
		state.transform.origin.y = floorcast.get_collision_point().y
		var floor_object = floorcast.get_collider()
		
		if floor_object is AnimatableBody3D:
			floor_velocity = floor_object.constant_linear_velocity
		else:
			floor_velocity = Vector3.ZERO
		
	constant_force = floor_velocity * mass	
	walk_velocity = linear_velocity - floor_velocity
		
	if not multiplayer.has_multiplayer_peer():
		pass	
				
	elif is_multiplayer_authority():
		AUTHORITY_POSITION = state.transform.origin					
	
	elif position.distance_to(AUTHORITY_POSITION) > 1.0:
		state.transform.origin = state.transform.origin.lerp(AUTHORITY_POSITION, 1.0)				
	
	else:
		state.transform.origin = state.transform.origin.lerp(AUTHORITY_POSITION, 0.05)
	
	var contact_count = state.get_contact_count()
	var index = 0
	
	while index < contact_count and is_multiplayer_authority():
	
		var normal = state.get_contact_local_normal(index)
		var impact = state.get_contact_impulse(index).length()
		
		if state.get_contact_collider_object(index) is RigidBody3D:		
			var their_velocity = state.get_contact_collider_velocity_at_position(index)
			var my_velocity = state.get_contact_local_velocity_at_position(index)
			var relative_velocity = their_velocity - my_velocity
			
			if my_velocity.length() < relative_velocity.length():	
				var kinetic_impulse = sqrt(relative_velocity.length())
				impact *= kinetic_impulse
		
		var shape = state.get_contact_local_shape(index)
		
		if shape == 0:
			impact *= pow((1.0 - normal.dot(Vector3.UP)/2), 1.25)		
		elif shape == 2:
			impact *= 1.5
				
		if impact >= IMPACT_THRESHOLD: 
			ragdoll_recovery_period_seconds = sqrt (impact / IMPACT_THRESHOLD)
			ragdoll.rpc()
			
		elif not ON_FLOOR:	
			var glancing = abs(LOOK_VECTOR.normalized().dot(normal)) <= 2.0/3.0	
			var forceful = impact > IMPACT_THRESHOLD/3.0
			var upright = abs(normal.dot(floor_normal)) <= 2.0/3.0
			var looking_forward = abs(LOOK_VECTOR.normalized().dot(floor_normal)) <= 3.0/4.0
			
			if glancing and forceful and upright and looking_forward:
				wall_jump.rpc(state.get_contact_impulse(index))
				
		index += 1
			
	var translational_velocity = Vector3(walk_velocity.x, 0, walk_velocity.z)
	var speed_target = TOPSPEED * TOPSPEED_MOD
	var impulse = Vector3.ZERO
		
	if RAGDOLLED:
		pass
		
	elif ON_FLOOR:
		
		if WALK_VECTOR == Vector3.ZERO:			
			impulse = -translational_velocity * get_acceleration() * mass
		else:
			impulse = WALK_VECTOR.normalized() * get_acceleration() * 2 * mass

	elif WALK_VECTOR:
		impulse = WALK_VECTOR * get_acceleration() * mass
		
	apply_central_force(impulse)
	
	if translational_velocity.length() > speed_target:
		var overshoot_scalar = (translational_velocity.length() / speed_target) - 1.0
		impulse = -translational_velocity * get_acceleration() * overshoot_scalar * mass
		apply_central_force(impulse)
			

func _physics_process(delta):
		
	if floorcast.enabled:
		reverse_coyote_timer = 0.0	
		
	elif reverse_coyote_timer >= coyote_duration:	
		floorcast.enabled = true
		
	else:	
		reverse_coyote_timer += delta

	if not is_on_floor():
		coyote_timer += delta	
			
	elif not ON_FLOOR and is_multiplayer_authority():		
		land.rpc()		
		
	else:
		coyote_timer = 0
	
	if not RAGDOLLED:
		ragdoll_cooldown_timer_seconds += delta	
	elif skeleton.ragdoll_is_at_rest():
		ragdoll_recovery_timer_seconds += delta
					
	if RAGDOLLED:
		skeleton.processRagdollOrientation(delta)
						
	elif ON_FLOOR:
		
		if WALK_VECTOR == Vector3.ZERO:		
			gravity_scale = 0.0
				
			if floorcast.enabled:
				linear_velocity.y = 0.0
				
			skeleton.processIdleOrientation(delta, LOOK_VECTOR)
			
		else:
			gravity_scale = 1.0
			skeleton.processWalkOrientation(delta , LOOK_VECTOR, WALK_VECTOR )
		
		var scalar = 5.0 * delta
		collider.shape.height = move_toward(collider.shape.height, 1.3, scalar)
		collider.position.y = move_toward(collider.position.y, .65, scalar)
		floorcast.target_position.y = move_toward(floorcast.target_position.y, -1.1, scalar)
		
	else:
		gravity_scale = 1.0
		skeleton.processFallOrientation(delta, LOOK_VECTOR, linear_velocity)	
		floor_velocity = floor_velocity.move_toward(Vector3.ZERO, (9.8 / 2.0) * delta)
		var jumpDeltaScale = clampf(animation.get("parameters/Jump/blend_position"), 0.0, 1.0)
		collider.shape.height = lerp(1.3, .8, jumpDeltaScale)
		collider.position.y = lerp(.65, .8, jumpDeltaScale)
		floorcast.target_position.y = lerp(-1.1, -.65, jumpDeltaScale)
		
	ON_FLOOR = coyote_timer <= coyote_duration
	rotation.y = fmod(rotation.y, 2*PI)
	collider2.transform = skeleton.bone_transform("neck")
	var upperBody = skeleton.bone_transform("upperBody")
	collider2.transform.basis = collider2.transform.basis.slerp(upperBody.basis, 0.7)
	collider2.transform.origin = collider2.transform.origin.slerp(upperBody.origin, 0.5)
	collider2.transform = collider2.transform.rotated(Vector3.UP, skeleton.rotation.y)
	collider3.transform.origin = skeleton.bone_transform("chin").origin
	collider3.transform.basis = skeleton.bone_transform("head").basis
	collider3.transform = collider3.transform.rotated(Vector3.UP, skeleton.rotation.y)
	
	
func is_on_floor():
	
	if floorcast.enabled:
		return floorcast.is_colliding()	
	else:
		return false 
		
	
func is_back_pedaling():
	
	var walkVec2 = Vector2(WALK_VECTOR.x, WALK_VECTOR.z).normalized()
	var lookVec2 = Vector2(LOOK_VECTOR.x, LOOK_VECTOR.z).normalized()
	return walkVec2.dot(lookVec2 ) > 0.25


func get_acceleration():
	
	if not ON_FLOOR:
		return 10.0		
		
	else:	
		var translationalSpeed = walk_velocity.length()
		return 10 + translationalSpeed 
		

func getRandomSkinTone():
	
	var rng = RandomNumberGenerator.new()
	var colorBase = rng.randf_range(40.0, 220.0 ) / 255
	var redShift = rng.randf_range(20,30 ) / 255
	var blueShift = rng.randf_range(0, redShift ) / 255
	SKIN_COLOR = Color(colorBase + redShift, colorBase, colorBase-blueShift )



func head_position():
	
	var headPosition = skeleton.bone_position("chin")
	var adjustedPosition = headPosition.rotated(Vector3.UP, skeleton.rotation.y ) 
	return adjustedPosition
	

func get_ragdoll_ready():
	
	return ragdoll_cooldown_timer_seconds > ragdoll_cooldown_period_seconds
	
	
func get_ragdoll_recovered():
	
	return ragdoll_recovery_timer_seconds > ragdoll_recovery_period_seconds
	

@rpc("call_local")
func ragdoll(velocity_override = Vector3.ZERO):
	
	if not RAGDOLLED:
		impactFX.bus = "stank"
		impactFX.volume_db = -12
		impactFX.pitch_scale = 1.0
		impactFX.play()
		
		if velocity_override != Vector3.ZERO:
			$"Skeleton3D/Ragdoll/Physical Bone lowerBody".linear_velocity = velocity_override
			$"Skeleton3D/Ragdoll/Physical Bone upperBody".linear_velocity = velocity_override
		else:
			$"Skeleton3D/Ragdoll/Physical Bone lowerBody".linear_velocity = linear_velocity
			$"Skeleton3D/Ragdoll/Physical Bone upperBody".linear_velocity = linear_velocity
			
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
func bump(velocity_impulse):
	
	if ON_FLOOR:
		ON_FLOOR = false
		coyote_timer = coyote_duration
		reverse_coyote_timer = 0.0
		floorcast.enabled = false
		apply_central_impulse(velocity_impulse * mass)
		

@rpc("call_local")
func jump():
	
	if ON_FLOOR:
		ON_FLOOR = false
		coyote_timer = coyote_duration
		reverse_coyote_timer = 0.0
		floorcast.enabled = false
		jumpFX.play()
		jumpFX.pitch_scale = 0.75
		var offset = max(0.0, linear_velocity.y)
		set_axis_velocity(Vector3.UP * (JUMP_SPEED + offset))
				
	elif DOUBLE_JUMP_CHARGES > 0:
		double_jump()
		

@rpc("call_local")
func wall_jump(impulse):
	
	apply_central_impulse(impulse)
	apply_central_impulse(Vector3.UP * JUMP_SPEED/2.0 * mass)
	reset_double_jump()
	impactFX.bus = "beef"
	impactFX.volume_db = -18
	impactFX.pitch_scale = 1.0
	impactFX.play()
	

@rpc("call_local")
func double_jump():
	
	if ON_FLOOR:
		pass	
		
	elif DOUBLE_JUMP_CHARGES > 0:
		jumpFX.pitch_scale = 1.25
		jumpFX.play()	
		DOUBLE_JUMP_CHARGES -= 1
		set_axis_velocity(Vector3.UP * JUMP_SPEED)
		

@rpc("call_local")
func reset_double_jump():
	
	DOUBLE_JUMP_CHARGES = 1
		
		
@rpc("call_local")
func land():
	
	reset_double_jump()
	coyote_timer = 0
	impactFX.bus = "beef"
	impactFX.volume_db = -27
	impactFX.pitch_scale = 0.5
	impactFX.play()
	var translational_velocity = Vector3(linear_velocity.x, 0, linear_velocity.z)
	var retardation_vector = -translational_velocity.normalized()
	var retardation_magnitude = max(1.0, translational_velocity.length()/2.0)
	var impulse = retardation_vector * retardation_magnitude * mass
	apply_central_impulse(impulse)

	
