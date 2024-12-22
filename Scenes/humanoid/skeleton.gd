extends Skeleton3D

@export var RAGDOLLED: bool = false
	
@onready var leftHand = $leftHandIK
@onready var rightHand = $rightHandIK
@onready var ragdollSkeleton = $Ragdoll

const LERP_VAL = 10.0


func _physics_process(delta):
	
	rotation.y = fmod(rotation.y, 2 * PI)
	
	if RAGDOLLED:
		pass
		
	else:	
		ragdollSkeleton.animate_physical_bones(delta)
		#ragdollSkeleton.correct_physical_bones()


func ragdoll_start():
	
	leftHand.stop()
	rightHand.stop()
	ragdollSkeleton.set_gravity(1.0)
	RAGDOLLED = true
	
	
func ragdoll_stop():
	
	leftHand.start()
	rightHand.start()
	ragdollSkeleton.set_gravity(0.0)
	ragdollSkeleton.reset_skeleton()
	RAGDOLLED = false
	

func processRagdollOrientation(_delta):
	leftHand.process_arm_falling(ragdollSkeleton.get_bone_global_pose_no_override(find_bone("head")))
	rightHand.process_arm_falling(ragdollSkeleton.get_bone_global_pose_no_override(find_bone("head")))


func processFallOrientation(delta, look_vector, walk_vector):

	walk_vector.y = 0
	walk_vector = walk_vector.normalized()
	
	ragdollSkeleton.LINEAR_STIFFNESS = 400.0
	ragdollSkeleton.ANGULAR_STIFFNESS = 400.0
	ragdollSkeleton.LINEAR_DAMPING = 20
	ragdollSkeleton.ANGULAR_DAMPING = 100
	ragdollSkeleton.bone_modifiers["foot.r"] = 0.25
	ragdollSkeleton.bone_modifiers["foot.l"] = 0.25
	ragdollSkeleton.bone_modifiers["toes.r"] = 1.0
	ragdollSkeleton.bone_modifiers["toes.l"] = 1.0
	
	leftHand.process_arm_falling(get_bone_global_pose_no_override(find_bone("foot.l")))
	rightHand.process_arm_falling(get_bone_global_pose_no_override(find_bone("foot.r")))
	
	var target_angle = atan2(-look_vector.x, -look_vector.z)

	if walk_vector == Vector3.ZERO:
		#print("Zero")
		smooth_turn(look_vector, target_angle, 10, delta)
		
	elif is_back_pedaling(look_vector, walk_vector):
		target_angle = atan2(-walk_vector.x, -walk_vector.z)
		var timeStep = LERP_VAL * delta
		rotation.y = lerp_angle(rotation.y, target_angle, timeStep/2)
		
	else:
		#print(walk_vector)
		target_angle = atan2(walk_vector.x, walk_vector.z)
		var timeStep = LERP_VAL * delta
		rotation.y = lerp_angle(rotation.y, target_angle, timeStep/2)


func processIdleOrientation(delta, look_vector):
	
	ragdollSkeleton.LINEAR_STIFFNESS = 400.0
	ragdollSkeleton.ANGULAR_STIFFNESS = 600.0
	ragdollSkeleton.LINEAR_DAMPING = 40
	ragdollSkeleton.ANGULAR_DAMPING = 60
	ragdollSkeleton.bone_modifiers["foot.r"] = 1.5
	ragdollSkeleton.bone_modifiers["foot.l"] = 1.5
	ragdollSkeleton.bone_modifiers["toes.r"] = 0.125
	ragdollSkeleton.bone_modifiers["toes.l"] = 0.125
	
	leftHand.process_arm_idle(get_bone_global_pose_no_override(find_bone("foot.l")))
	rightHand.process_arm_idle(get_bone_global_pose_no_override(find_bone("foot.r")))

	var target_angle = atan2(-look_vector.x, -look_vector.z)
	smooth_turn(look_vector, target_angle, 10, delta)


func processWalkOrientation(delta, look_vector, walk_vector):
	
	ragdollSkeleton.LINEAR_STIFFNESS = 800.0
	ragdollSkeleton.ANGULAR_STIFFNESS = 1000.0
	ragdollSkeleton.LINEAR_DAMPING = 40
	ragdollSkeleton.ANGULAR_DAMPING = 80
	ragdollSkeleton.bone_modifiers["foot.r"] = 1.0
	ragdollSkeleton.bone_modifiers["foot.l"] = 1.0
	ragdollSkeleton.bone_modifiers["toes.r"] = 0.125
	ragdollSkeleton.bone_modifiers["toes.l"] = 0.125
	

	leftHand.process_arm_sway(get_bone_global_pose_no_override(find_bone("foot.l")))
	rightHand.process_arm_sway(get_bone_global_pose_no_override(find_bone("foot.r")))
	
	var timeStep = LERP_VAL * delta
	var actual = rotation.y
	var target
	
	if is_back_pedaling(look_vector, walk_vector):
		target = atan2(-walk_vector.x, -walk_vector.z)
		
	else:
		target = atan2(walk_vector.x, walk_vector.z)
		
	var lookTarget = atan2(-look_vector.x, -look_vector.z)
	var lookDiff = get_true_difference(actual, lookTarget)
	
	if lookDiff > PI/2:
		rotation.y = lerp_angle(actual, lookTarget, timeStep/5)
		
	if lookDiff == 0:
		turn_velocity = 0
		turn_locked_in = false
		
	else: 
		turn_velocity = min(turn_velocity + delta*turn_acceleration, turn_top_speed)
		rotation.y = lerp_angle(actual, target, timeStep)


func processSkeletonRotation(look_vector, ratio, scalar):
	
	var lookAngle = get_relative_look_angle(look_vector)
	var look_relative = Vector3(-look_vector.y, lookAngle, 0)
	var headScale = ratio * scalar
	var bodyScale = (1.0-ratio)*scalar
	var upperBody_rotation = look_relative * Vector3(bodyScale, bodyScale, 0)
	var head_rotation = look_relative * Vector3(headScale, headScale, 0)
	set_bone_pose_rotation(find_bone("upperBody"), Quaternion.from_euler(upperBody_rotation))
	set_bone_pose_rotation(find_bone("head"), Quaternion.from_euler(head_rotation + Vector3.BACK * -lookAngle/4))
	

@onready var currentReacher = null
func processReach(look_vector, reaching):
	
	if currentReacher:
		currentReacher.process_arm_forward(get_bone_global_pose_no_override(find_bone("head")))
		
	var lookAngle = get_relative_look_angle(look_vector)
	var deadband = PI/5
	
	if !reaching && currentReacher != null:
		currentReacher = null
		ragdollSkeleton.toggle_physical_bone_collider("upperArm.r", true)
		ragdollSkeleton.toggle_physical_bone_collider("lowerArm.r", true)
		ragdollSkeleton.toggle_physical_bone_collider("upperArm.l", true)
		ragdollSkeleton.toggle_physical_bone_collider("lowerArm.l", true)
	
	elif !reaching:
		pass
	
	elif lookAngle > deadband && currentReacher != leftHand:
		currentReacher = leftHand
		ragdollSkeleton.toggle_physical_bone_collider("upperArm.r", true)
		ragdollSkeleton.toggle_physical_bone_collider("lowerArm.r", true)
		ragdollSkeleton.toggle_physical_bone_collider("upperArm.l", false)
		ragdollSkeleton.toggle_physical_bone_collider("lowerArm.l", false)
	
	elif lookAngle < -deadband && currentReacher != rightHand:
		currentReacher = rightHand
		ragdollSkeleton.toggle_physical_bone_collider("upperArm.r", false)
		ragdollSkeleton.toggle_physical_bone_collider("lowerArm.r", false)
		ragdollSkeleton.toggle_physical_bone_collider("upperArm.l", true)
		ragdollSkeleton.toggle_physical_bone_collider("lowerArm.l", true)
	
	elif currentReacher == null:
		currentReacher = rightHand
		ragdollSkeleton.toggle_physical_bone_collider("upperArm.r", false)
		ragdollSkeleton.toggle_physical_bone_collider("lowerArm.r", false)
		ragdollSkeleton.toggle_physical_bone_collider("upperArm.l", true)
		ragdollSkeleton.toggle_physical_bone_collider("lowerArm.l", true)


func get_relative_look_angle(look_vector):
	
	var lookAngle = Vector2(-look_vector.z, -look_vector.x).angle() - fmod(rotation.y, 2*PI)
	
	if abs(lookAngle) > PI:
		lookAngle -= 2 * PI * sign(lookAngle)
	
	return lookAngle


func isLookingBack(look_vector, threshold = 0.25):
	
	return Vector2(sin(rotation.y), cos(rotation.y)).dot(Vector2(-look_vector.x, -look_vector.z)) < threshold


func is_back_pedaling(look_vector, walk_vector):
	
	var walkVec2 = Vector2(walk_vector.x, walk_vector.z).normalized()
	var lookVec2 = Vector2(look_vector.x, look_vector.z).normalized()
	return walkVec2.dot(lookVec2) > 0.25


func ragdoll_is_at_rest():
	
	var ragdollVelocity = ragdollSkeleton.ragdoll_velocity()
	return ragdollVelocity.length() <= 0.25


func bone_position(bone_name):
	
	return ragdollSkeleton.get_bone_global_pose(ragdollSkeleton.find_bone(bone_name)).origin
	
	
func bone_rotation(bone_name):
	
	return ragdollSkeleton.get_bone_global_pose(ragdollSkeleton.find_bone(bone_name)).basis.get_euler()
	
	
func bone_transform(bone_name):
	
	return ragdollSkeleton.get_bone_global_pose(ragdollSkeleton.find_bone(bone_name))		
	

func ragdoll_position():
	
	var ragdollBonePosition = ragdollSkeleton.get_bone_global_pose(ragdollSkeleton.find_bone("upperBody")).origin
	return to_global(ragdollSkeleton.position + ragdollBonePosition)


func get_true_difference(actual, target):
	
	actual = fmod(actual + 2*PI, 2*PI)
	target = fmod(target + 2*PI, 2*PI)
	var difference = target-actual
	var overlapDifference = target - 2*PI + actual
	return min(abs(difference),abs(overlapDifference))


func get_shortest_path(actual, target):
	
	actual = fmod(actual + 2*PI, 2*PI)
	target = fmod(target + 2*PI, 2*PI)
	var difference = target-actual
	var overlapDifference = target - 2*PI + actual
	
	if difference <=overlapDifference:
		return sign(difference)
	
	else:
		return sign(overlapDifference)
	
	
func get_ragdoll_bone_position(bone_name):
	return ragdollSkeleton.get_bone_global_pose_no_override(ragdollSkeleton.find_bone(bone_name))


var turn_velocity = 0
var turn_acceleration = 5
var turn_locked_in = false
var turn_top_speed = 3
func smooth_turn(look_vector, target_angle, speed, delta):
	
	if isLookingBack(look_vector, 0.25):
		turn_locked_in = true
		
	var difference = get_true_difference(rotation.y, target_angle)
	
	if turn_locked_in:
		turn_velocity = min(turn_velocity + delta * turn_acceleration, turn_top_speed)
		var step_scale = 5
		var step_size = delta * step_scale * turn_velocity
		rotation.y = lerp_angle(rotation.y, target_angle, step_size)
		
		if not isLookingBack(look_vector, .95):
			turn_locked_in = false
			
	elif abs(difference) >= PI/2:
		rotation.y = lerp_angle(rotation.y, target_angle, delta * speed)
		
	else:
		turn_velocity = 0
		
		
		
