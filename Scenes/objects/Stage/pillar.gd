@tool
extends Node3D


@onready var mesh = $MeshInstance3D
@onready var collider = $CollisionShape3D
@onready var raycast = $RayCast3D


var bottom = Vector3.ZERO
var top_height = 0.75


func _process(delta):

	if not raycast.is_colliding():
		pass
		
	elif raycast.get_collision_point() != bottom:
		bottom = raycast.get_collision_point()
		var top = global_position + Vector3.UP * top_height
		
		var actual_position = bottom.lerp(top, 0.5)
		
		mesh.global_position = actual_position
		collider.global_position = actual_position
		
		var actual_height = top.y - bottom.y + top_height
		
		mesh.mesh.height = actual_height 
		collider.shape.height = actual_height
