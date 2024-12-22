extends Node3D


enum Preference{
	shallow = 0,
	deep = 1
}

@export var preference = Preference.deep

@onready var mesh = $MeshInstance3D
@onready var collider = $CollisionShape3D
@onready var raycast = $RayCast3D

@export var bottom_drop = 0.0
@export var top_height = 0.0
@export var radius = 0.5

var bottom_position = Vector3.ZERO


func _process(_delta):
		
	if not raycast.is_colliding():
		pass
		
	elif raycast.get_collision_point() != bottom_position:
		
		var new_point = raycast.get_collision_point()
		
		if just_deeper(new_point) and preference == Preference.shallow:
			return
		elif just_shallower(new_point) and preference == Preference.deep:
			return
		
		bottom_position = new_point - global_position
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


func just_deeper(new_point):
	
	var new_trajectory = (new_point - global_position)
	
	if bottom_position.normalized() != new_trajectory.normalized():
		return false
	elif new_trajectory.length() > bottom_position.length():
		return true
	else:
		return false
		

func just_shallower(new_point):
	
	var new_trajectory = (new_point - global_position)
	
	if bottom_position.normalized() != new_trajectory.normalized():
		return false
	elif new_trajectory.length() < bottom_position.length():
		return true
	else:
		return false


func get_top_position(bottom_position):
	
	return bottom_position.normalized() * top_height * -1.0


func get_mesh_position(bottom_position):
	
	var top_position = get_top_position(bottom_position)
	var extra_drop = (bottom_position - top_position).normalized() * bottom_drop
	return (bottom_position + extra_drop).lerp(top_position, 0.5)	
	
	
func get_mesh_height(bottom_position):
	
	var top_position = get_top_position(bottom_position)
	return top_position.distance_to(bottom_position) + bottom_drop
	

