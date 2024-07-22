extends Skeleton3D

@export var RAGDOLLED = false

@export var LINEAR_STIFFNESS = 500.0
@export var LINEAR_DAMPING = 40.0

@export var ANGULAR_STIFFNESS = 800.0
@export var ANGULAR_DAMPING = 80.0

@onready var Animated_Skeleton : Skeleton3D = get_parent()
@onready var rootBone = $"Physical Bone lowerBody"

@onready var physicalBones = []
@onready var mockBoneIndices = []

const MAX_VELOCITY = 100
const MAX_DISPLACEMENT = 2
const MAX_ANGULAR_DISPLACEMENT = PI*2

func _ready():
	physical_bones_start_simulation()	
	for index in range(0, get_bone_count()-1):
		mockBoneIndices.append(index)
	for child in get_children():
		if child is PhysicalBone3D:
			physicalBones.append(child)
			var indexToRemove = mockBoneIndices.find(find_bone(child.bone_name))
			mockBoneIndices.remove_at(indexToRemove)

func animate_physical_bones(delta):
	for boneIndex in mockBoneIndices:
		instantly_match_animated_bone(boneIndex)
	for physical_bone in physicalBones:
		var physical_transform = get_physical_transform(physical_bone)
		var animated_transform = get_animated_transform(physical_bone)	
		var linear_displacement = animated_transform.origin - physical_transform.origin
		var angular_displacement = animated_transform.basis * physical_transform.basis.inverse()
		#var tooFast = physical_bone.linear_velocity.length() >= MAX_VELOCITY
		#var tooFar = linear_displacement.length() >= MAX_DISPLACEMENT
		#var tooBent = angular_displacement.get_euler().length() >= MAX_ANGULAR_DISPLACEMENT
		#if tooFast or tooFar:
			#physical_bone.linear_velocity = Vector3.ZERO
			#physical_bone.angular_velocity = Vector3.ZERO
			##instantly_match_animated_bone(physical_bone.get_bone_id())
		#else:
		var linear_force = get_hookes_law_force(LINEAR_STIFFNESS, linear_displacement, LINEAR_DAMPING, physical_bone.linear_velocity)
		physical_bone.linear_velocity += linear_force * delta
		var angular_torque = get_hookes_law_force(ANGULAR_STIFFNESS, angular_displacement.get_euler(), ANGULAR_DAMPING, physical_bone.angular_velocity)
		physical_bone.angular_velocity += angular_torque * delta
			#instantly_match_animated_bone(physical_bone.get_bone_id())

func set_gravity(value):
	for bone in physicalBones:
		bone.gravity_scale = value

func get_hookes_law_force(stiffness, displacement, damping, velocity):
	return (stiffness * displacement) - (damping * velocity)

func ragdoll_velocity():
	return rootBone.linear_velocity
	
func get_animated_transform(physical_bone):
	var animated_index = Animated_Skeleton.find_bone(physical_bone.bone_name)
	return Animated_Skeleton.global_transform * Animated_Skeleton.get_bone_global_pose(animated_index)

func get_physical_transform(physical_bone):
	var physical_index = physical_bone.get_bone_id()
	return global_transform * get_bone_global_pose(physical_index)
	
func set_physical_transform(physical_bone, new_transform):
	var physical_index = physical_bone.get_bone_id()
	set_bone_global_pose_override(physical_index, new_transform, 1)
	
func instantly_match_animated_bone(boneIndex):
	set_bone_pose_position(boneIndex, Animated_Skeleton.get_bone_pose_position(boneIndex))
	set_bone_pose_rotation(boneIndex, Animated_Skeleton.get_bone_pose_rotation(boneIndex))

func reset_skeleton():
	for index in range(0, get_bone_count()-1):
		instantly_match_animated_bone(index)
