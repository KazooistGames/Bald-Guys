extends Skeleton3D

@export var RAGDOLLED = false

@export var LINEAR_STIFFNESS = 500.0
@export var LINEAR_DAMPING = 40.0

@export var ANGULAR_STIFFNESS = 800.0
@export var ANGULAR_DAMPING = 80.0

var bone_modifiers = {
	"head":1.0,
	"upperBody":0.75,
	"upperArm.r":0.5,
	"upperArm.l":0.5,
	"lowerArm.r":0.25,
	"lowerArm.l":0.25,
	"lowerBody":1.25,
	"upperLeg.r":0.75,
	"upperLeg.l":0.75,
	"lowerLeg.r":0.5,
	"lowerLeg.l":0.5,
	"foot.r":1.0,
	"foot.l":1.0,
	"toes.r":0.125,
	"toes.l":0.125,
}

@onready var Animated_Skeleton : Skeleton3D = get_parent()
@onready var rootBone = $"Physical Bone lowerBody"

@onready var physicalBones = []
@onready var mockBoneIndices = []

const MAX_VELOCITY = 100
const MAX_DISPLACEMENT = 2
const MAX_ANGULAR_DISPLACEMENT = PI

@export var correction_trigger = false

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
		if(correction_trigger):
			var animated_transform = get_animated_transform(physical_bone)
			physical_bone.position = animated_transform.origin
			physical_bone.rotation = animated_transform.basis.get_euler()
		else:		
			var bone_modifier = bone_modifiers.get(physical_bone.bone_name, 1.0)
			var physical_transform = get_physical_transform(physical_bone)
			var animated_transform = get_animated_transform(physical_bone)	
			var linear_displacement = animated_transform.origin - physical_transform.origin
			var angular_displacement = animated_transform.basis * physical_transform.basis.inverse()
			var tooFast = physical_bone.linear_velocity.length() >= MAX_VELOCITY
			var tooFar = linear_displacement.length() >= MAX_DISPLACEMENT
			var tooBent = angular_displacement.get_euler().length() >= MAX_ANGULAR_DISPLACEMENT
			if tooFast or tooFar:
				physical_bone.linear_velocity = Vector3.ZERO
				physical_bone.angular_velocity = Vector3.ZERO
				instantly_match_animated_bone(physical_bone.get_bone_id())
			#elif tooBent:
				#instantly_match_animated_bone(physical_bone.get_bone_id())
			else:
				var linear_force = get_hookes_law_force(LINEAR_STIFFNESS * bone_modifier, linear_displacement, LINEAR_DAMPING * bone_modifier, physical_bone.linear_velocity)
				physical_bone.linear_velocity += linear_force * delta
				var angular_torque = get_hookes_law_force(ANGULAR_STIFFNESS * bone_modifier, angular_displacement.get_euler(), ANGULAR_DAMPING * bone_modifier, physical_bone.angular_velocity)
				physical_bone.angular_velocity += angular_torque * delta

	correction_trigger = false
	
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
	if mockBoneIndices.has(boneIndex):
		set_bone_pose_position(boneIndex, Animated_Skeleton.get_bone_pose_position(boneIndex))
		set_bone_pose_rotation(boneIndex, Animated_Skeleton.get_bone_pose_rotation(boneIndex))
	else:
		for physical_bone in physicalBones:
			if(find_bone(physical_bone.bone_name) == boneIndex):
				var animated_transform = get_animated_transform(physical_bone)
				physical_bone.position = animated_transform.origin
				physical_bone.rotation = animated_transform.basis.get_euler()
			
func reset_skeleton():
	for index in range(0, get_bone_count()-1):
		instantly_match_animated_bone(index)
		
func toggle_physical_bone_collider(bone_name, value):
	for bone in physicalBones:
		if bone.bone_name == bone_name:
			bone.get_child(0).disabled = not value
