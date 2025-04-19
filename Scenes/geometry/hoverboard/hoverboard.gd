extends AnimatableBody3D

enum HoverStatus {
	idle = 0,
	flying = 1,
	manual = 2,
}
@export var status : HoverStatus = HoverStatus.idle

@export var size  : float = 3.0 :
	get:
		return size
	set(value):	
		mesh.mesh.size.z = value 
		mesh.mesh.size.x = value
		collider.shape.size.x = value
		collider.shape.size.z = value
		
@export var girth : float = 0.25 : 
	get:
		return size
	set(value):	
		mesh.mesh.size.y = value
		collider.shape.size.y = value
				
@export var upper_limits : Vector3 = Vector3(50, 50, 50)
@export var lower_limits : Vector3 = Vector3(-50, -50, -50)
@export var trajectory : Vector3 = Vector3.ZERO
@export var speed : float = 0.0
@export var throttle : float = 0.0
@export var external_speed : float = 0.0
@export var disable_constrain : bool = false
@export var disable_bounce : bool = false
@export var disable_depenetration : bool = false

@onready var mesh : MeshInstance3D = $MeshInstance3D
@onready var collider : CollisionShape3D = $CollisionShape3D

var target_speed : float
var query : PhysicsShapeQueryParameters3D

signal bounced()
signal constrained()


func _ready():
	
	depenetrate_geometry()
	
	query = PhysicsShapeQueryParameters3D.new()	
	query.shape = collider.shape
	query.collision_mask = 0b0001		
	query.exclude = [get_rid(), self.get_parent_node_3d()]
	mesh.mesh.size.x = size
	mesh.mesh.size.y = girth
	mesh.mesh.size.z = size 	
	collider.shape.size.x = size
	collider.shape.size.y = girth
	collider.shape.size.z = size


func _physics_process(delta):
	
	if status == HoverStatus.idle:
		target_speed = 0.0
	elif status == HoverStatus.flying:
		target_speed = speed
	elif status == HoverStatus.manual:
		target_speed = external_speed
		
	var acceleration = max(0.5, throttle * 2.0)
	throttle = move_toward(throttle, target_speed, acceleration * delta)
	position += trajectory * throttle * delta
	
	var penetration = Vector3.ZERO
	
	if not disable_depenetration:
		penetration = depenetrate_geometry()
		
	if not disable_bounce:
		bounce_geometry(penetration)
		
	if not disable_constrain:
		constrain_geometry()


func depenetrate_geometry() -> Vector3:
	
	var starting_trajectory = trajectory
	var intersections = get_collider_intersections(trajectory)
	
	if intersections == null or intersections.size() == 0:
		return Vector3.ZERO
					
	var penetration = intersections[0] - intersections[1] 
	position -= penetration
	
	return penetration


func bounce_geometry(penetration : Vector3):
	
	var starting_trajectory = trajectory
		
	if penetration == Vector3.ZERO:
		return trajectory 
		
	elif abs(penetration.y) >= abs(penetration.x) and abs(penetration.y) >= abs(penetration.z):	
		trajectory.y *= -1.0		
					
	elif abs(penetration.x) >= abs(penetration.z):
		trajectory.x *= -1.0
		
	else:
		trajectory.z *= -1.0	
	
	if starting_trajectory != trajectory:
		bounced.emit()
	
	return trajectory
	

func constrain_geometry():
	
	var starting_trajectory = trajectory
	#	X
	if position.x > upper_limits.x:
		trajectory.x *= -1.0	
		position.x = upper_limits.x
		
	elif position.x < lower_limits.x:
		trajectory.x *= -1.0	
		position.x = lower_limits.x
	#	Y
	if position.y >= upper_limits.y:
		trajectory.y *= -1.0	
		position.y = upper_limits.y
			
	elif position.y <= lower_limits.y + girth:
		trajectory.y *= -1.0		
		position.y = lower_limits.y + girth
	#	Z
	if position.z > upper_limits.z:
		trajectory.z *= -1.0
		position.z = upper_limits.z
		
	elif position.z < lower_limits.z:
		trajectory.z *= -1.0	
		position.z = lower_limits.z
		
	if starting_trajectory != trajectory:
		constrained.emit()
		
	return trajectory
		
		
func get_collider_intersections(trajectory):
	
	var physics_state = get_world_3d().direct_space_state
	
	query.transform = collider.global_transform
	query.motion = trajectory
		
	var result = physics_state.collide_shape(query)

	return result 
	


	

		

	



		
	
	
	
	
	
	
	
	
	
	
