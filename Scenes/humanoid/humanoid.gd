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

@export var floor_velocity = Vector3(0,0,0)
@export var walk_velocity = Vector3.ZERO

@onready var skeleton = $Skeleton3D
@onready var animation = $AnimationTree

@onready var leg_collider = $CollisionShapeLegs
@onready var chest_collider = $CollisionShapeChest
@onready var head_collider = $CollisionShapeHead

@onready var synchronizer = $MultiplayerSynchronizer
@onready var floorcast = $FloorCast3D

@onready var impactFX = $ImpactAudio
@onready var jumpFX = $JumpAudio

var TOPSPEED = 0
var TOPSPEED_MOD = 1

var IMPACT_THRESHOLD =  6.5
var ragdoll_cooldown_period_seconds = 0.5
var ragdoll_cooldown_timer_seconds = 0

var ragdoll_recovery_progress = 0.0
var ragdoll_recovery_default_duration = 3.0
var ragdoll_recovery_default_boost = 0.1

signal ragdolled

var coyote_timer = 0.0
var coyote_duration = 0.1
var reverse_coyote_timer = 0.0


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
	TOPSPEED = SPEED_GEARS.y if RUNNING else SPEED_GEARS.x
	
	if RAGDOLLED:
		pass
		
	elif ON_FLOOR:

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
				var kinetic_impulse = pow(relative_velocity.length(), 0.75)
				impact *= kinetic_impulse
		
		var shape = state.get_contact_local_shape(index)
		
		if shape == 0:
			impact *= pow((1.0 - normal.dot(Vector3.UP)/2.0), 1.25)		
		elif shape == 2:
			impact *= 1.5
				
		if impact >= IMPACT_THRESHOLD: 

			#ragdoll_recovery_period_seconds = sqrt (impact / IMPACT_THRESHOLD)
			ragdoll.rpc()
			
		elif not ON_FLOOR:	
			var glancing = abs(LOOK_VECTOR.normalized().dot(normal)) <= 0.667
			var forceful = impact > IMPACT_THRESHOLD/3.0
			var upright = abs(normal.dot(floor_normal)) <= 0.667
			var looking_forward = abs(LOOK_VECTOR.normalized().dot(floor_normal)) <= 0.75
			
			if glancing and forceful and upright and looking_forward:
				wall_jump.rpc(state.get_contact_impulse(index))
				
		index += 1			

var floor_object = null
var cached_floor_obj = null
var cached_floor_pos = Vector3.ZERO


func _physics_process(delta):		
			
	floor_object = floorcast.get_collider()
	
	if floor_object == null:
		pass
		
	elif floor_object == cached_floor_obj:
		floor_velocity = (floor_object.position - cached_floor_pos) / delta
		cached_floor_pos = floor_object.position
		
	else:
		cached_floor_pos = floor_object.position
		floor_velocity = Vector3.ZERO
		
	cached_floor_obj = floor_object
	constant_force = floor_velocity * mass	
	walk_velocity = linear_velocity - floor_velocity
	
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
	else:
		var ragdoll_velocity = max(1.0, $"Skeleton3D/Ragdoll/Physical Bone lowerBody".linear_velocity.length())
		var recovery_scalar = ragdoll_recovery_default_duration * sqrt(ragdoll_velocity)
		ragdoll_recovery_progress += delta / recovery_scalar
		#ragdoll_recovery_timer_seconds += delta
					
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
			#apply_central_force(WALK_VECTOR.normalized() * get_acceleration() * mass)
			skeleton.processWalkOrientation(delta , LOOK_VECTOR, WALK_VECTOR )
			
		var scalar = 5.0 * delta
		leg_collider.shape.height = move_toward(leg_collider.shape.height, 1.3, scalar)
		leg_collider.position.y = move_toward(leg_collider.position.y, .65, scalar)
		floorcast.target_position.y = move_toward(floorcast.target_position.y, -1.1, scalar)
		
	else:
		gravity_scale = 1.0
		#apply_central_force(WALK_VECTOR.normalized() * get_acceleration() * mass)
		skeleton.processFallOrientation(delta, LOOK_VECTOR, linear_velocity)	
		floor_velocity = floor_velocity.move_toward(Vector3.ZERO, (9.8 / 3.0) * delta)
		var jumpDeltaScale = clampf(animation.get("parameters/Jump/blend_position"), 0.0, 1.0)
		leg_collider.shape.height = lerp(1.3, .8, jumpDeltaScale)
		leg_collider.position.y = lerp(.65, .8, jumpDeltaScale)
		floorcast.target_position.y = lerp(-1.1, -.65, jumpDeltaScale)
		
	ON_FLOOR = coyote_timer <= coyote_duration
	rotation.y = fmod(rotation.y, 2*PI)
	
	chest_collider.transform = skeleton.bone_transform("neck")
	var upperBody = skeleton.bone_transform("upperBody")
	chest_collider.transform.basis = chest_collider.transform.basis.slerp(upperBody.basis.orthonormalized(), 0.7)
	chest_collider.position = chest_collider.transform.origin.slerp(upperBody.origin, 0.5)	
	chest_collider.position += Vector3(0, 0.05, 0.0)
	chest_collider.transform = chest_collider.transform.rotated(Vector3.UP, skeleton.rotation.y)

	head_collider.position = skeleton.bone_transform("chin").origin
	head_collider.rotation = skeleton.bone_rotation("head")
	head_collider.transform = head_collider.transform.rotated(Vector3.UP, skeleton.rotation.y)
	
	#var step = get_acceleration() * delta
	var walk_target
	
	if ON_FLOOR or WALK_VECTOR:
		walk_target = WALK_VECTOR.normalized() * TOPSPEED * TOPSPEED_MOD
	else:
		walk_target = linear_velocity - floor_velocity
		
	var target_linear_velocity = walk_target + floor_velocity
	target_linear_velocity.y = linear_velocity.y
	linear_velocity = linear_velocity.move_toward(target_linear_velocity, get_acceleration() * delta)
	
	#print(linear_velocity.length())
	
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
		return 10 + translationalSpeed * 4
		

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
	
	#return ragdoll_recovery_timer_seconds > ragdoll_recovery_period_seconds
	return ragdoll_recovery_progress >= 1.0
	

@rpc("call_local", "reliable")
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
			
		RUNNING = true
		ragdolled.emit()
		skeleton.ragdoll_start()
		#ragdoll_recovery_timer_seconds = 0
		ragdoll_recovery_progress = 0.0
		animation.active = false
		leg_collider.disabled = true
		head_collider.disabled = true
		chest_collider.disabled = true
		RAGDOLLED = true
		freeze = true
		
		
@rpc("call_local", "reliable")
func unragdoll():
	
	if RAGDOLLED:
		ragdoll_cooldown_timer_seconds = 0
		position = skeleton.ragdoll_position()
		skeleton.ragdoll_stop()
		animation.active = true
		leg_collider.disabled = false
		chest_collider.disabled = false
		head_collider.disabled = false
		RAGDOLLED = false
		freeze = false

@rpc("call_local", "reliable")
func lunge(velocity_impulse):
	
	if ON_FLOOR:
		ON_FLOOR = false
		coyote_timer = coyote_duration
		reverse_coyote_timer = 0.0
		floorcast.enabled = false
		
	linear_velocity = velocity_impulse

@rpc("call_local", "reliable")
func bump(velocity_impulse):
	
	if ON_FLOOR:
		ON_FLOOR = false
		coyote_timer = coyote_duration
		reverse_coyote_timer = 0.0
		floorcast.enabled = false
		
	apply_central_impulse(velocity_impulse * mass)
		

@rpc("call_local", "reliable")
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
		

@rpc("call_local", "reliable")
func wall_jump(impulse):
	
	apply_central_impulse(impulse)
	apply_central_impulse(Vector3.UP * JUMP_SPEED/2.0 * mass)
	reset_double_jump()
	impactFX.bus = "beef"
	impactFX.volume_db = -18
	impactFX.pitch_scale = 1.0
	impactFX.play()
	

@rpc("call_local", "reliable")
func double_jump():
	
	if ON_FLOOR:
		pass	
		
	elif DOUBLE_JUMP_CHARGES > 0:
		jumpFX.pitch_scale = 1.25
		jumpFX.play()	
		DOUBLE_JUMP_CHARGES -= 1
		set_axis_velocity(Vector3.UP * JUMP_SPEED)
		

@rpc("call_local", "reliable")
func reset_double_jump():
	
	DOUBLE_JUMP_CHARGES = 1
		
		
@rpc("call_local", "reliable")
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

	
