extends RigidBody3D

const floor_normal = Vector3(0, 1, 0)
const floor_dot_product = 1.0 / 2.0

const Lunge_Deadband = 0.75
const Lunge_Speed = 15
const Lunge_max_traversal = 6

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
@export var JUMP_SPEED = 5.5
@export var RUNNING = false
@export var DOUBLE_JUMP_CHARGES = 1

@export var floor_velocity = Vector3(0,0,0)
@export var walk_velocity = Vector3.ZERO

@onready var skeleton = $Skeleton3D
@onready var animation = $AnimationTree

@onready var leg_collider = $CollisionShapeLegs
@onready var chest_collider = $CollisionShapeChest
@onready var head_collider = $CollisionShapeHead

@onready var floorcast = $FloorCast3D

@onready var boofFX = $RagdollAudio
@onready var impactFX = $StaticImpactAudio
@onready var jumpFX = $JumpAudio

@onready var force = $Force

@onready var synchronizer = $MultiplayerSynchronizer
@onready var unlagger = $LagCompensator
@onready var rectifier = $StateRectifier

var multiplayer_permissive = false

var TOPSPEED = 0
var TOPSPEED_MOD = 1

var RAGDOLL_THRESHOLD =  6.5
var ragdoll_cooldown_period_seconds = 0.5
var ragdoll_cooldown_timer_seconds = 0

var ragdoll_recovery_progress = 0.0
var ragdoll_recovery_default_duration = 3.0
var ragdoll_recovery_default_boost = 0.1

var coyote_timer = 0.0
var coyote_duration = 0.15
var reverse_coyote_timer = 0.0

var floor_object = null
var cached_floor_obj = null
var cached_floor_pos = Vector3.ZERO

var just_jumped_timer = 0.0
var just_jumped_period = 1.0/3.0

var Lunging = false
var Lunge_Target : Node3D 
var lunge_target_last_position = Vector3.ZERO
var lunge_total_traversal

var depen_query : PhysicsShapeQueryParameters3D

var wall_jump_ons = true
var collision_ons : Array = []

signal ragdoll_change(new_state)
signal ragdolled
signal unragdolled


func _enter_tree():
	
	add_to_group("humanoids")


func _ready():
	
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 5
	
	if is_multiplayer_authority(): 
		getRandomSkinTone()
		unlagger.max_rectification_scalar = 1.2
		
	depen_query = PhysicsShapeQueryParameters3D.new()	
	depen_query.collision_mask = 0b0001		
	depen_query.exclude = [get_rid(), self.get_parent_node_3d()]
	

func _process(_delta):
	
	if not multiplayer.has_multiplayer_peer():
		multiplayer_permissive = true
	elif is_multiplayer_authority():
		multiplayer_permissive = true
	else:
		multiplayer_permissive = false
			
	if not RAGDOLLED: #ragdoll cooldown
		pass		
	elif get_ragdoll_recovered() and is_multiplayer_authority(): 
		unragdoll.rpc()
		
	var allow_run = run_permissive()
	
	animation.walkAnimBlendScalar = TOPSPEED
	animation.walkAnimPlaybackScalar = 1.5 if allow_run else 2.0
	animation.WALK_STATE = animation.WalkState.RUNNING if allow_run else animation.WalkState.WALKING
	
	RAGDOLL_THRESHOLD = 6.0 * mass
	TOPSPEED = SPEED_GEARS.y if allow_run else SPEED_GEARS.x
	
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
	
	var something_big_happened = false
	
	if not is_on_floor() or RAGDOLLED:
		pass		
		
	elif state.transform.origin.distance_to(floorcast.get_collision_point()) <= floorcast.target_position.length():
		state.transform.origin.y = floorcast.get_collision_point().y
	
	var contact_count = state.get_contact_count()
	var index = 0
	
	while index < contact_count and multiplayer_permissive: # loop through all objects we collided with this frame
		
		var them = state.get_contact_collider_object(index)
		
		if collision_ons.has(them):
			index += 1
			continue
		else:	
			collision_ons.append(them)
		
		var normal = state.get_contact_local_normal(index)
		var impact = state.get_contact_impulse(index).length()
		#perform object-type specific logic
		if state.get_contact_collider_object(index) is RigidBody3D: #other "loose" items		 
			var their_velocity = state.get_contact_collider_velocity_at_position(index)
			var my_velocity = state.get_contact_local_velocity_at_position(index)
			var relative_velocity = their_velocity - my_velocity
			
			if my_velocity.length() < relative_velocity.length():	
				var kinetic_impulse = pow(relative_velocity.length(), 0.75)
				impact *= kinetic_impulse
				
		else: #unstoppable/immovable objects
			pass

		var shape = state.get_contact_local_shape(index)
		
		if shape == 0:
			impact *= pow((1.0 - normal.dot(Vector3.UP)/2.0), 1.25)		
		elif shape == 2:
			impact *= 1.5
			
		var wall_jumped = false
		var bumped = true
		
		if impact < RAGDOLL_THRESHOLD/3.0: # too small of impact, ignore
			bumped = false
					
		elif abs(normal.dot(floor_normal)) > floor_dot_product: #hitting the floor, ignore
			bumped = false
				
		elif is_on_floor():	# not aerial, ignore
			pass
			
		else: #calculate timing and angle to know if wall jump succeeds
			var glancing = abs(LOOK_VECTOR.normalized().dot(normal)) <= 2.0/3.0
			var just_jumped = just_jumped_timer <= just_jumped_period
			wall_jumped = glancing and just_jumped 
		
		if wall_jumped: #wall jump success overrides ragdoll
			wall_jump.rpc(state.get_contact_impulse(index))
			something_big_happened = true
			
		elif impact >= RAGDOLL_THRESHOLD and not RAGDOLLED:
			var impacter = state.get_contact_collider_object(index)
			print(name, " knocked down by ", impacter)
			something_big_happened = true
			ragdoll.rpc()
			
		elif bumped:
			bump.rpc(state.get_contact_impulse(index) / 1.6 / mass)
			
		index += 1	
				
	return something_big_happened

func _physics_process(delta):	
	collision_ons.clear()
	force.external_velocity = linear_velocity
	
	if floorcast.enabled:
		reverse_coyote_timer = 0.0			
	elif reverse_coyote_timer >= coyote_duration:	
		floorcast.enabled = true		
	else:	
		reverse_coyote_timer += delta

	if not is_on_floor():
		coyote_timer += delta	
		just_jumped_timer += delta	
			
	elif not ON_FLOOR and is_multiplayer_authority():		
		land.rpc()			
			
	else:
		coyote_timer = 0
		just_jumped_timer = 0.0
		
	if not RAGDOLLED:
		ragdoll_cooldown_timer_seconds += delta	
	else:
		var ragdoll_velocity = max(1.0, $"Skeleton3D/Ragdoll/Physical Bone lowerBody".linear_velocity.length())
		var recovery_scalar = ragdoll_recovery_default_duration * sqrt(ragdoll_velocity)
		ragdoll_recovery_progress += delta / recovery_scalar
		#ragdoll_recovery_timer_seconds += delta
					
	if RAGDOLLED:
		skeleton.processRagdollOrientation(delta)
		Lunging = false
						
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
		leg_collider.shape.height = move_toward(leg_collider.shape.height, 1.3, scalar)
		leg_collider.position.y = move_toward(leg_collider.position.y, .65, scalar)
		floorcast.target_position.y = move_toward(floorcast.target_position.y, -1.1, scalar)
		
	else:
		gravity_scale = 1.0
		skeleton.processFallOrientation(delta, LOOK_VECTOR, linear_velocity)	
		#floor_velocity = floor_velocity.move_toward(Vector3.ZERO, (9.8 / 3.0) * delta)
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
	
	return step_movement(delta)
	
	
func step_movement(delta):
		
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

	if Lunging: 
		
		if Lunge_Target == null:	
				
			if multiplayer_permissive:
				unlunge.rpc()
				
			return
			
		lunge_total_traversal += linear_velocity.length() * delta
		var lunge_expired = lunge_total_traversal >= Lunge_max_traversal
		
		if lunge_expired and multiplayer_permissive:
			unlunge.rpc()
			
		var disposition = Lunge_Target.global_position - global_position
		var in_range = disposition.length() <= Lunge_Deadband
		
		if in_range and multiplayer_permissive:
			unlunge.rpc()
			
		else:
			var deadband_next_frame_stepsize = (disposition.length() - Lunge_Deadband) / delta
			var intercept_position = Lunge_Target.global_position + Lunge_Target.linear_velocity * delta
			var intercept_route = (intercept_position - global_position).normalized()
			linear_velocity = intercept_route * min(Lunge_Speed, deadband_next_frame_stepsize * 1.1)
			
	else:	
		var transversal_walk_target
		var walk_speed = TOPSPEED * TOPSPEED_MOD
		
		if not ON_FLOOR:
			floor_velocity = floor_velocity.move_toward(Vector3.ZERO, (9.8 / 3.0) * delta)
			
		if ON_FLOOR or WALK_VECTOR:
			transversal_walk_target = WALK_VECTOR.normalized() * walk_speed
			
			if ON_FLOOR:
				transversal_walk_target.y = linear_velocity.y
				transversal_walk_target = transversal_walk_target.normalized() * walk_speed				
			
		else:
			transversal_walk_target = linear_velocity - floor_velocity
			
		var target_linear_velocity = transversal_walk_target + floor_velocity
		target_linear_velocity.y = linear_velocity.y
		linear_velocity = linear_velocity.move_toward(target_linear_velocity, get_acceleration() * delta)
		
	return linear_velocity * delta
	
	
func run_permissive():
	
	if not RUNNING:
		return false
	elif force.action == force.Action.charging:
		return false
	elif force.action == force.Action.cooldown:
		return false
	elif WALK_VECTOR.normalized().dot(LOOK_VECTOR.normalized()) > 0.1:
		return false		
	elif WALK_VECTOR == Vector3.ZERO:
		return false
	else:
		return true
		
		
func is_on_floor():
	
	if not floorcast.enabled:
		return false
	elif not floorcast.is_colliding():
		return false
	elif abs(linear_velocity.y) >= JUMP_SPEED:
		return false
	elif floorcast.get_collision_normal().dot(Vector3.UP) > floor_dot_product:
		return true 
		
	
func is_back_pedaling():
	
	var walkVec2 = Vector2(WALK_VECTOR.x, WALK_VECTOR.z).normalized()
	var lookVec2 = Vector2(LOOK_VECTOR.x, LOOK_VECTOR.z).normalized()
	return walkVec2.dot(lookVec2 ) > 0.25


func get_acceleration():
	
	if not ON_FLOOR:
		return 10.0		
	else:	
		var translationalSpeed = walk_velocity.length()
		return 15 + translationalSpeed * 2
		

func getRandomSkinTone():
	
	var rng = RandomNumberGenerator.new()
	var colorBase = rng.randf_range(20.0, 240.0 ) / 255
	var redShift = rng.randf_range(20,45 ) / 255
	var blueShift = rng.randf_range(0, redShift ) / 255
	SKIN_COLOR = Color(colorBase + redShift, colorBase, colorBase-blueShift )


func head_position():
	
	var headPosition = skeleton.bone_position("chin")
	var adjustedPosition = headPosition.rotated(Vector3.UP, skeleton.rotation.y ) 
	return adjustedPosition
	

func get_ragdoll_ready():
	
	return ragdoll_cooldown_timer_seconds > ragdoll_cooldown_period_seconds
	
	
func get_ragdoll_recovered():
	
	return ragdoll_recovery_progress >= 1.0
	

@rpc("call_local", "reliable")
func ragdoll(velocity_override = Vector3.ZERO):
	
	if not RAGDOLLED:
		audio_boof(-15, 1.0)
		
		if velocity_override != Vector3.ZERO:
			$"Skeleton3D/Ragdoll/Physical Bone lowerBody".linear_velocity = velocity_override
			$"Skeleton3D/Ragdoll/Physical Bone upperBody".linear_velocity = velocity_override
		else:
			$"Skeleton3D/Ragdoll/Physical Bone lowerBody".linear_velocity = linear_velocity
			$"Skeleton3D/Ragdoll/Physical Bone upperBody".linear_velocity = linear_velocity
			
		ragdolled.emit()
		skeleton.ragdoll_start()
		ragdoll_recovery_progress = 0.0
		animation.active = false
		leg_collider.disabled = true
		head_collider.disabled = true
		chest_collider.disabled = true
		RAGDOLLED = true
		freeze = true
		ragdoll_change.emit(RAGDOLLED, self)	
		force.rpc_reset()
		floor_velocity = Vector3.ZERO
		
		
@rpc("call_local", "reliable")
func unragdoll(use_skeleton_position : bool = true):
	
	if RAGDOLLED:
		ragdoll_cooldown_timer_seconds = 0
		
		if use_skeleton_position:
			position = skeleton.ragdoll_position()
			
		skeleton.ragdoll_stop()
		animation.active = true
		leg_collider.disabled = false
		chest_collider.disabled = false
		head_collider.disabled = false
		RAGDOLLED = false
		freeze = false
		ragdoll_change.emit(RAGDOLLED, self)
		unragdolled.emit()
		floor_velocity = Vector3.ZERO


@rpc("call_local", "reliable")
func lunge(target_node_path):
	
	var target_node = get_node(target_node_path)
	
	if target_node == null:
		print("Null lunge target: " + target_node_path)
		return
	
	if ON_FLOOR:
		ON_FLOOR = false
		coyote_timer = coyote_duration
		reverse_coyote_timer = 0.0
		floorcast.enabled = false
	
	leg_collider.disabled = true
	Lunge_Target = target_node
	lunge_target_last_position = Lunge_Target.global_position
	lunge_total_traversal = 0
	Lunging = true
	skeleton.lunge_start()
	
	
@rpc("call_local", "reliable")
func unlunge():	
	
	leg_collider.disabled = false
	Lunging = false
	linear_velocity = Vector3.ZERO
	skeleton.lunge_stop()


@rpc("call_local", "reliable")
func bump(velocity_impulse):
	
	ON_FLOOR = false
	coyote_timer = coyote_duration
	reverse_coyote_timer = 0.0
	floorcast.enabled = false
	audio_impact(-36, 0.60)
	apply_central_impulse(velocity_impulse * mass)

@rpc("call_local", "reliable")
func jump():
	
	ON_FLOOR = false
	wall_jump_ons = true
	just_jumped_timer = 0.0
	coyote_timer = coyote_duration
	reverse_coyote_timer = 0.0
	floorcast.enabled = false
	audio_jump(0.8)
	var offset = max(0.0, linear_velocity.y)
	var new_y_speed = JUMP_SPEED + offset
	linear_velocity.y = new_y_speed
		

@rpc("call_local", "reliable")
func double_jump():
	wall_jump_ons = true
	just_jumped_timer = 0.0
	audio_jump(1.2)
	DOUBLE_JUMP_CHARGES -= 1
	linear_velocity.y = max(JUMP_SPEED, linear_velocity.y)
	
	
@rpc("call_local", "reliable")
func wall_jump(impulse):
	
	if wall_jump_ons:
		linear_velocity.x += impulse.x / mass
		linear_velocity.y += JUMP_SPEED/2.0
		linear_velocity.z += impulse.z / mass
		var speed_boost = impulse.normalized() * JUMP_SPEED / 2.0
		floor_velocity += speed_boost
		wall_jump_ons = false
		reset_double_jump()	
		audio_jump(1.6)
		audio_impact(-18, 1.2)
		
		if is_multiplayer_authority():
			rectifier.clear_old_data(0)


@rpc("call_local", "reliable")
func reset_double_jump():
	
	DOUBLE_JUMP_CHARGES = 1
		
		
@rpc("call_local", "reliable")
func land():
	
	reset_double_jump()
	coyote_timer = 0
	audio_impact(-24, 0.5)
	
	var translational_velocity = Vector3(linear_velocity.x, 0, linear_velocity.z)
	var deadstop_point = 2.0
	
	
	if translational_velocity.length() <= deadstop_point:
		linear_velocity.x = 0
		linear_velocity.z = 0
		
	elif translational_velocity.length() <= deadstop_point * 2.0:
		linear_velocity.x = move_toward(linear_velocity.x, 0.0, 1.5)
		linear_velocity.z = move_toward(linear_velocity.z, 0.0, 1.5)
		
	else:
		linear_velocity.x /= 2.0
		linear_velocity.z /= 2.0
	

	
	
func rollback(lag : float) -> void:

	rectifier.perform_rollback(lag)
	force_update_transform()
	collision_ons.clear()
	wall_jump_ons = true
	coyote_timer -= lag		
	coyote_timer = max(coyote_timer, 0.)
	ON_FLOOR = coyote_timer <= coyote_duration
	reverse_coyote_timer -= lag
	reverse_coyote_timer = max(reverse_coyote_timer, 0.)
	floorcast.enabled = reverse_coyote_timer < coyote_duration
	just_jumped_timer -= lag * 2.0 #fudge factor :)
	just_jumped_timer = max(just_jumped_timer, 0.)
	var ragdoll_velocity = max(1.0, $"Skeleton3D/Ragdoll/Physical Bone lowerBody".linear_velocity.length())
	var recovery_scalar = ragdoll_recovery_default_duration * sqrt(ragdoll_velocity)
	ragdoll_recovery_progress -= lag / recovery_scalar
	ragdoll_recovery_progress = max(ragdoll_recovery_progress, 0.)
	#print("Rolled back to ", position, " moving at ", linear_velocity)


func predict(lag : float) -> void:
	
	var step_size : float
	var position_delta : Vector3 
	var rid = get_rid()
	
	while lag > 0:
		step_size = min(get_physics_process_delta_time(), lag)
		lag -= step_size
		position_delta = _physics_process(step_size)
		position += position_delta
		depenetrate_geometry(leg_collider)
		depenetrate_geometry(chest_collider)
		force_update_transform()
		
		if not ON_FLOOR:
			linear_velocity -= Vector3.UP * 9.8 * step_size
			
		var state = PhysicsServer3D.body_get_direct_state(rid)
		state.linear_velocity = linear_velocity
		state.transform.origin = position
			
		state.integrate_forces()
		rectifier.cache(lag)
		
	#print("predicted up to ", position, " moving at ", linear_velocity)
	
	
func depenetrate_geometry(collider : CollisionShape3D) -> Vector3:
	
	#var starting_trajectory = trajectory
	var intersections = get_collider_intersections(collider, linear_velocity)
	
	if intersections == null or intersections.size() == 0:
		return Vector3.ZERO
					
	var penetration = intersections[0] - intersections[1] 
	position -= penetration
	
	return penetration	


func get_collider_intersections(collider : CollisionShape3D, motion : Vector3):
	
	var physics_state = get_world_3d().direct_space_state	
	depen_query.transform = collider.global_transform
	depen_query.motion = motion
	depen_query.shape = collider.shape
	var result = physics_state.collide_shape(depen_query)

	return result 


func audio_boof(db, pitch):
	boofFX.bus = "stank"
	boofFX.volume_db = db
	boofFX.pitch_scale = pitch
	boofFX.play()
	
func audio_impact(db, pitch):
	impactFX.bus = "beef"
	impactFX.volume_db = db
	impactFX.pitch_scale = pitch
	impactFX.play()	
	
func audio_jump(pitch):
	jumpFX.pitch_scale = pitch
	jumpFX.play()	
