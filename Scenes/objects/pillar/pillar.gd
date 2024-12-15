extends Node3D


@onready var mesh = $MeshInstance3D
@onready var collider = $CollisionShape3D
@onready var raycast = $RayCast3D


@export var top_height = 0.0
@export var radius = 0.5

var bottom_position = Vector3.ZERO


func _process(_delta):
		
	if not raycast.is_colliding():
		pass
		
	elif raycast.get_collision_point() != bottom_position:
		
		bottom_position = raycast.get_collision_point() - global_position
		var top_position = get_top_position(bottom_position)
		
		var mesh_position = get_mesh_position(bottom_position)
		var mesh_height = get_mesh_height(bottom_position)
			
		mesh.global_position = mesh_position + global_position
		mesh.mesh.height = mesh_height 
		mesh.mesh.top_radius = radius
		mesh.mesh.bottom_radius = radius
		
		collider.global_position = mesh_position + global_position
		collider.shape.height = mesh_height
		collider.shape.radius = radius


func get_top_position(bottom_position):
	
	return bottom_position.normalized() * top_height * -1.0


func get_mesh_position(bottom_position):
	
	var top_position = get_top_position(bottom_position)
	return bottom_position.lerp(top_position, 0.5)	
	
	
func get_mesh_height(bottom_position):
	
	var top_position = get_top_position(bottom_position)
	return top_position.distance_to(bottom_position)
	
	
