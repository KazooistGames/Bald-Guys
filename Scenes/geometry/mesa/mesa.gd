extends Node3D


enum Preference{
	inert = -1,
	shallow = 0,
	deep = 1,
	none = 2,
}

@export var preference = Preference.deep

@onready var mesh = $MeshInstance3D
@onready var collider = $CollisionShape3D
@onready var raycast = $RayCast3D

@export var top_height = 0.0
@export var bottom_drop = 0.0
@export var size = 0.5

var bottom_position = Vector3.ZERO


func _process(_delta):
	
	if not raycast.is_colliding() or preference == Preference.inert:
		bottom_position = raycast.target_position
		
	elif raycast.get_collision_point() != bottom_position:
		
		var new_point = raycast.get_collision_point()
		
		if just_deeper(new_point) and preference == Preference.shallow:
			return
		elif just_shallower(new_point) and preference == Preference.deep:
			return
		else:
			bottom_position = new_point - global_position
		
	rerender(bottom_position)


func get_top_position(bot_pos):
	
	return bot_pos.normalized() * top_height * -1.0


func get_mesh_position(bot_pos):
	
	var top_position = get_top_position(bot_pos)
	return bot_pos.lerp(top_position, 0.5)	
	
	
func get_mesh_height(bot_pos):
	
	var top_position = get_top_position(bot_pos)
	return top_position.distance_to(bot_pos) + bottom_drop
	
	
func rerender(bottom):

	var mesh_position = get_mesh_position(bottom)
	var mesh_height = get_mesh_height(bottom)
		
	mesh.global_position = mesh_position + global_position
	mesh.mesh.size.x = size
	mesh.mesh.size.y = size
	mesh.mesh.size.z = mesh_height 
	
	collider.global_position = mesh_position + global_position
	collider.shape.size.y = mesh_height
	collider.shape.size.x = size
	collider.shape.size.z = size
		
		
func just_deeper(new_point):
	
	var new_trajectory = (new_point - global_position)
	
	if (bottom_position.normalized() - new_trajectory.normalized()).length() >= 0.25:
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
