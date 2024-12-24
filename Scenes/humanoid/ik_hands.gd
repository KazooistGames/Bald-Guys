extends SkeletonIK3D

@export var swayWidthBase = 0.18
var swayHeightBase = 1.0

@export var idleOffset = Vector3(0,0,0)

var axisOfRotation = Vector3.ZERO

var forwardRotation = Vector3(PI, PI, PI)

var lerp_scalar = 1.0

var targeted_node = null


func _ready():
	
	targeted_node = get_node(target_node)
	start()
	
	
func _process(delta):
	
	if is_running() and lerp_scalar < 1.0:
		lerp_scalar += delta
		
	else:
		lerp_scalar = 0
		
	lerp_scalar = clampf(lerp_scalar, 0.0, 1.0)
	
	
func process_arm_forward(headTransform):
	use_magnet = true
	var xSign = sign(idleOffset.x)
	magnet = Vector3(2 * xSign, 0, 0)
	var targetTransform = targeted_node.transform
	var offset = Vector3(.2 * xSign, .2, 0)
	var scalar = 1.25
	targetTransform.origin = headTransform.basis.z * scalar + headTransform.origin + offset
	targetTransform.origin.z = max(targetTransform.origin.z, 0.2)
	targeted_node.transform = targeted_node.transform.interpolate_with(targetTransform, 1.0 * lerp_scalar)
	
	
func process_arm_sway(footTransform, magnitude = 1.0):
	use_magnet = true
	reset_magnet()
	#magnet = Vector3(0, 1, -1)
	
	var xSign = sign(idleOffset.x)
	var targetTransform = footTransform
	var swayHeight = swayHeightBase
	var swayWidth = swayWidthBase
	var swayLength = -0.6 * magnitude
	targetTransform.basis = get_hand_rest().basis.rotated(Vector3(-1,sign(idleOffset.x),0).normalized(), PI/6)
	
	if targetTransform.origin.z < 0:
		axisOfRotation = Vector3(1.5,0,sign(idleOffset.x)).normalized()
		swayHeight += abs(footTransform.origin.z) / (3.0 - magnitude)

	else:
		axisOfRotation = Vector3(1,0,sign(idleOffset.x)).normalized()
		#swayWidth -= abs(footTransform.origin.z) / (4.0)
		swayLength *= 3.0
		
	targetTransform.basis = targetTransform.basis.rotated(axisOfRotation, 2.5*footTransform.origin.z)
	targetTransform.origin *= Vector3(1, 0, swayLength)
	targetTransform.origin += Vector3(swayWidth * xSign, swayHeight, 0)
	get_node(target_node).transform = get_node(target_node).transform.interpolate_with(targetTransform, 0.75 * lerp_scalar)


func process_arm_idle(footTransform):
	use_magnet = false
	reset_magnet()
	var targetTransform = footTransform
	targetTransform.origin.y /= 2
	targetTransform.origin += idleOffset
	targetTransform.basis = get_hand_rest().basis.rotated(Vector3(-1,sign(idleOffset.x),0).normalized(), PI/6)
	targetTransform.basis = targetTransform.basis.rotated(Vector3.RIGHT, -PI * footTransform.origin.y)
	get_node(target_node).transform = get_node(target_node).transform.interpolate_with(targetTransform, 0.15 * lerp_scalar)


func process_arm_falling(footTransform):
	use_magnet = false
	reset_magnet()
	var targetTransform = footTransform
	targetTransform.origin.x *= 3.25
	targetTransform.origin.y = 0.9 + footTransform.origin.y/1.5
	targetTransform.origin.z *= 2.5
	var side = sign(idleOffset.x)
	targetTransform.basis = get_hand_rest().basis.rotated(Vector3(-1,0,0).normalized(), PI/3 * (footTransform.origin.y*2))
	targetTransform.basis = targetTransform.basis.rotated(Vector3.FORWARD, side * PI * footTransform.origin.y)
	targetTransform.basis = targetTransform.basis.rotated(Vector3.DOWN,side * PI/9)
	get_node(target_node).transform = get_node(target_node).transform.interpolate_with(targetTransform, 0.25 * lerp_scalar)


func get_hand_rest():
	
	var skel = get_parent_skeleton()
	return skel.get_bone_rest(skel.find_bone(tip_bone))
	
func reset_magnet():
	
	magnet.x = sign(idleOffset.x)
	magnet.y = 0
	magnet.z = -1
