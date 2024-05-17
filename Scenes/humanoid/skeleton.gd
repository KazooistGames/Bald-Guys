extends Skeleton3D

@export var RAGDOLLED = false
@onready var leftHand = $leftHandIK
@onready var rightHand = $rightHandIK
@onready var ragdollSkeleton = $Ragdoll

const LERP_VAL = 9.0

func _physics_process(delta):
	if RAGDOLLED:
		leftHand.stop()
		rightHand.stop()
		ragdollSkeleton.set_gravity(1.0)
	else:	
		leftHand.start()
		rightHand.start()
		ragdollSkeleton.animate_physical_bones(delta)
		ragdollSkeleton.set_gravity(0.0)
	
func processRagdollOrientation(delta):
	#position = ragdollSkeleton.position
	pass
	
func processFallOrientation(delta, look_vector):
	ragdollSkeleton.LINEAR_STIFFNESS = 800.0
	ragdollSkeleton.ANGULAR_STIFFNESS = 1200.0
	var timeStep = LERP_VAL * delta
	leftHand.process_arm_falling(get_bone_global_pose_no_override(find_bone("foot.l")))
	rightHand.process_arm_falling(get_bone_global_pose_no_override(find_bone("foot.r")))
	rotation.y = lerp_angle(rotation.y, atan2(-look_vector.x, -look_vector.z), timeStep/3)

func processIdleOrientation(delta, look_vector):
	ragdollSkeleton.LINEAR_STIFFNESS = 400.0
	ragdollSkeleton.ANGULAR_STIFFNESS = 600.0
	var timeStep = LERP_VAL * delta
	leftHand.process_arm_idle(get_bone_global_pose_no_override(find_bone("foot.l")))
	rightHand.process_arm_idle(get_bone_global_pose_no_override(find_bone("foot.r")))
	if isLookingBack(look_vector):
		var difference = abs(atan2(-look_vector.x, -look_vector.z) - rotation.y)
		#var smoothStep = difference*timeStep/100
		rotation.y = lerp_angle(rotation.y, atan2(-look_vector.x, -look_vector.z), min(difference,timeStep/3))

func processWalkOrientation(delta, look_vector, walk_vector):
	ragdollSkeleton.LINEAR_STIFFNESS = 900.0
	ragdollSkeleton.ANGULAR_STIFFNESS = 1200.0
	var timeStep = LERP_VAL * delta
	leftHand.process_arm_sway(get_bone_global_pose_no_override(find_bone("foot.l")))
	rightHand.process_arm_sway(get_bone_global_pose_no_override(find_bone("foot.r")))
	var actual = rotation.y
	var target = atan2(-walk_vector.x, -walk_vector.z) if is_back_pedaling(look_vector, walk_vector) else atan2(walk_vector.x, walk_vector.z)
	var lookTarget = atan2(-look_vector.x, -look_vector.z)
	var diff = get_true_difference(actual, target)
	var lookDiff = get_true_difference(actual, lookTarget)
	if lookDiff > PI/2:
		rotation.y = lerp_angle(actual, lookTarget, timeStep)
	else: 
		rotation.y = lerp_angle(actual, target, timeStep)
		
func processSkeletonRotation(look_vector):
	var lookAngle = get_relative_look_angle(look_vector)
	var look_relative = Vector3(-look_vector.y, lookAngle, 0)
	var upperBody_rotation = look_relative * Vector3(0.4, 0.4, 0)
	var head_rotation = look_relative * Vector3(0.6, 0.6, 0)
	set_bone_pose_rotation(find_bone("upperBody"), Quaternion.from_euler(upperBody_rotation))
	set_bone_pose_rotation(find_bone("head"), Quaternion.from_euler(head_rotation + Vector3.BACK * -lookAngle/4))

@onready var currentReacher = rightHand
func processReach(look_vector):
	var lookAngle = get_relative_look_angle(look_vector)
	var deadBand = PI/4
	if lookAngle > deadBand:
		currentReacher = leftHand
	elif lookAngle < -deadBand:
		currentReacher = rightHand
	currentReacher.process_arm_forward(get_bone_global_pose_no_override(find_bone("head")))

func get_relative_look_angle(look_vector):
	var lookAngle = Vector2(-look_vector.z, -look_vector.x).angle() - fmod(rotation.y, 2*PI)
	if abs(lookAngle) > PI:
		lookAngle -= 2 * PI * sign(lookAngle)
	return lookAngle
	
func isLookingBack(look_vector):
	return Vector2(sin(rotation.y), cos(rotation.y)).dot(Vector2(-look_vector.x, -look_vector.z)) < 0.5

func is_back_pedaling(look_vector, walk_vector):
	var walkVec2 = Vector2(walk_vector.x, walk_vector.z).normalized()
	var lookVec2 = Vector2(look_vector.x, look_vector.z).normalized()
	return walkVec2.dot(lookVec2) > 0
	
func ragdoll_is_at_rest():
	var ragdollVelocity = ragdollSkeleton.ragdoll_velocity()
	return ragdollVelocity.length() <= 0.5
	
func head_position():
	return ragdollSkeleton.get_bone_global_pose(ragdollSkeleton.find_bone("chin")).origin

func ragdoll_position():
	var ragdollBonePosition = ragdollSkeleton.get_bone_global_pose(ragdollSkeleton.find_bone("upperBody")).origin
	return to_global(ragdollSkeleton.position + ragdollBonePosition)

func get_true_difference(actual, target):
	actual = fmod(actual + 2*PI, 2*PI)
	target = fmod(target + 2*PI, 2*PI)
	var difference = target-actual
	var overlapDifference = target - 2*PI + actual
	return min(abs(difference),abs(overlapDifference))
