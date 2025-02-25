extends Node3D


enum Preference{
	locked = -1,
	shallow = 0,
	deep = 1,
	none = 2,
}

@export var preference = Preference.deep
	
@onready var mesh = $MeshInstance3D
@onready var collider = $CollisionShape3D
@onready var raycast = $RayCast3D

@export var top_height : float = 0.0		
@export var bottom_drop  : float = 0.25
@export var radius = 0.0

@export var reverse_growth_scale = 0.0
@export var bottom_position = Vector3.ZERO

var raycast_target = Vector3.DOWN * 100


func _ready():
		
	rerender()
	

func _physics_process(_delta):
	
	raycast.target_position = raycast_target
	
	if preference == Preference.locked:
		return
		
	elif not raycast.is_colliding():
		
		if bottom_position != raycast.target_position:	
			bottom_position = raycast.target_position
		else:
			return
		
	elif raycast.get_collision_point() != bottom_position:
		
		var new_point = raycast.get_collision_point()
		
		if just_deeper(new_point) and preference == Preference.shallow:
			return
		elif just_shallower(new_point) and preference == Preference.deep:
			return
		else:
			bottom_position = new_point - global_position
		
	rerender()


func get_top_position(bot_pos):
	
	return bot_pos.normalized() * top_height * -1.0


func get_mesh_position(bot_pos):
	
	var top_position = get_top_position(bot_pos)
	return bot_pos.lerp(top_position, 0.5)	
	
	
func get_mesh_height(bot_pos):
	
	var top_position = get_top_position(bot_pos)
	return top_position.distance_to(bot_pos) 
	
	
func rerender():
		
	var mesh_position = get_mesh_position(bottom_position) * reverse_growth_scale
	var mesh_height = get_mesh_height(bottom_position) * reverse_growth_scale
		
	if radius <= 0 or mesh_height <= 0:
		return		
		
	mesh.global_position = mesh_position + global_position
	mesh.mesh.height = mesh_height 
	mesh.mesh.top_radius = radius
	mesh.mesh.bottom_radius = radius
	
	collider.global_position = mesh_position + global_position
	collider.shape.height = mesh_height
	collider.shape.radius = radius
	
		
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
		
	
	
	
	
	
	
	
	
	
	
