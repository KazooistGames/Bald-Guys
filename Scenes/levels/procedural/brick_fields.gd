extends Node3D


const brick_prefab = preload("res://Scenes/objects/brick/brick.tscn")
var bricks = []


func spawn_field(rows, columns, spacing, spawn_point):
	
	print("dropping ", rows * columns, " bricks")
	
	var new_bricks = []
	var span = spacing / 2.0
	
	for row_num in range(rows):
		var z_offset = (row_num - rows / 2.0) * spacing
		
		for col_num in range(columns):
			var x_offset = (col_num - columns / 2.0) * spacing
			var new_brick = brick_prefab.instantiate()
			add_child(new_brick, true)
			new_brick.position = spawn_point + Vector3(x_offset, 0, z_offset)
			
		 

