extends Skeleton3D

const MAX_VELOCITY = 100
const MAX_DISPLACEMENT = 5.0
const MAX_ANGULAR_DISPLACEMENT = 2 * PI
const perfect_match = true

@export var RAGDOLLED = false
@export var LINEAR_STIFFNESS = 500.0
@export var LINEAR_DAMPING = 40.0
@export var ANGULAR_STIFFNESS = 800.0
@export var ANGULAR_DAMPING = 80.0
@export var head_displacement = 0.0

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
@onready var physicalBones : Array = []
@onready var mockBoneIndices = []
@onready var slappy_foot_left = $"Physical Bone foot_l/SlappyFoot"
@onready var slappy_foot_right = $"Physical Bone foot_r/SlappyFoot"

var correct_physical_bones_trigger

func _ready():
	
	physical_bones_start_simulation()	
	
	for index in range(0, get_bone_count()-1):
		mockBoneIndices.append(index)
		
	for child in get_children():
		
		if child is PhysicalBone3D:
			physicalBones.append(child)
			var indexToRemove = mockBoneIndices.find(find_bone(child.bone_name))
			
			if indexToRemove >= 0:
				mockBoneIndices.remove_at(indexToRemove)
				
				
func animate_physical_bones(delta):
	
	for boneIndex in mockBoneIndices:
		instantly_match_animated_bone(boneIndex)
		
	for physical_bone in physicalBones:	
			
		var bone_modifier = bone_modifiers.get(physical_bone.bone_name, 1.0)
		var physical_transform = get_physical_transform(physical_bone)
		var animated_transform = get_animated_transform(physical_bone)	
		var linear_displacement = animated_transform.origin - physical_transform.origin
		var angular_displacement = animated_transform.basis * physical_transform.basis.inverse()

		if(correct_physical_bones_trigger):
			physical_bone.linear_velocity = Vector3.ZERO
			physical_bone.angular_velocity = Vector3.ZERO
			physical_bone.position = physical_bone.position.lerp(animated_transform.origin, 1)
			physical_bone.rotation = physical_bone.rotation.lerp(animated_transform.basis.get_euler(), 1)
			correct_physical_bones_trigger = false
			
		else:
			var lin_stiff = LINEAR_STIFFNESS * bone_modifier
			var lin_damp = LINEAR_DAMPING * bone_modifier
			var linear_force = hookes_law(lin_stiff, linear_displacement, lin_damp, physical_bone.linear_velocity)
			physical_bone.linear_velocity += linear_force * delta		
			var ang_stiff = ANGULAR_STIFFNESS * bone_modifier
			var ang_damp = ANGULAR_DAMPING * bone_modifier
			var ang_vel = physical_bone.angular_velocity
			var angular_torq = hookes_law(ang_stiff, angular_displacement.get_euler(), ang_damp, ang_vel)
			physical_bone.angular_velocity += angular_torq * delta
			
		if physical_bone.bone_name == "head":
			head_displacement = linear_displacement.length()
			
	process_slappy_feet(delta)
	

func process_slappy_feet(delta):
	
	var speed = $"Physical Bone lowerBody".linear_velocity.length()
	var speed_scaled = pow(speed, 1.25)
	slappy_foot_left.mod_db = speed_scaled
	slappy_foot_right.mod_db = speed_scaled
	slappy_foot_left.process_slap(delta)
	slappy_foot_right.process_slap(delta)


func set_gravity(value):
	
	for bone in physicalBones:
		bone.gravity_scale = value


func hookes_law(stiffness, displacement, damping, velocity):
	
	var centering_force = (stiffness * displacement)
	var damping_force = (damping * velocity)
	return centering_force - damping_force


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
		
			
func reset_skeleton():
	
	correct_physical_bones_trigger = true
	
	for index in range(0, get_bone_count()-1):
		instantly_match_animated_bone(index)
		
		
func toggle_physical_bone_collider(bone_name, value):
	
	for bone in physicalBones:
			
		if bone.bone_name == bone_name:
			bone.get_child(0).disabled = not value


func sync_loose_bones():
	
	if not multiplayer.has_multiplayer_peer():
		pass
		
	elif not is_multiplayer_authority():
		return
	
	for bone : PhysicalBone3D in physicalBones:	
		var path = bone.get_path()
		rpc_set_bone_physics.rpc(path, bone.transform, bone.linear_velocity)
		
		
@rpc("call_remote", "authority")
func rpc_set_bone_physics(bone_path : NodePath, new_transform : Transform3D, new_velocity : Vector3):
	
	var bone : PhysicsBody3D = get_node(bone_path)
	bone.transform = bone.transform.interpolate_with(new_transform, 0.5)
	bone.linear_velocity = bone.linear_velocity.move_toward(new_velocity, 0.25)
		
	
	
