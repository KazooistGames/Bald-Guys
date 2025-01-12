extends Node3D

const prefab = preload("res://Scenes/geometry/mesa/mesa.tscn")

const board_thickness = 0.5

const map_size = 50


func _physics_process(delta):
	
	var boards = get_boards()
	
	for index in range(boards.size()): #move hover mesas	
		var body = boards[index]
		var intersection = get_collider_intersections(body)
		var xz_bounds = body.size / 2.05
		var y_bounds = body.raycast.target_position.length() / 2.0
		var trajectory = body.constant_linear_velocity
		
		if intersection == null:
			pass
					
		else:
			
			if abs(intersection.x) >= xz_bounds and intersection.x >= intersection.z:
				var x_pen = (xz_bounds - abs(intersection.x)) * sign(intersection.x)
				body.position.x += x_pen
				trajectory.x = -trajectory.x 
		
			elif abs(intersection.z) >= xz_bounds:
				var z_pen = (xz_bounds - abs(intersection.z)) * sign(intersection.z)
				body.position.z += z_pen
				trajectory.z = -trajectory.z 
				
			elif abs(intersection.y) >= y_bounds:
				var y_pen = (y_bounds - abs(intersection.y)) * sign(intersection.y)
				body.position.y -= y_pen
				trajectory.y = -trajectory.y

		if body.position.y > 15:
			trajectory.y = -trajectory.y
			body.position.y = 15
			
		elif body.position.y < 0:
			trajectory.y = -trajectory.y
			body.position.y = 0

		body.position += trajectory * delta
		body.constant_linear_velocity = trajectory
		
		
func get_collider_intersections(body):
	
	var physics_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = body.collider.shape
	query.transform = body.collider.global_transform
	query.motion = body.constant_linear_velocity
	query.exclude = [body.get_rid(), self.get_parent_node_3d()]
	query.collision_mask = 0b0001
	var result = physics_state.collide_shape(query)
	
	if result.size() > 0:
		var offset = result[0] - body.collider.global_transform.origin
		return offset 
		
		
func spawn_hover_boards(count):
	
	for index in range(count): #create hovering platforms
		var new_board = prefab.instantiate()
		add_child(new_board, true)		
		new_board.size =  3
		var boundary = map_size / 2.0 - new_board.size / 2.0
		new_board.bottom_drop = 0.0
		new_board.preference = new_board.Preference.deep
		new_board.raycast.target_position = Vector3.DOWN * board_thickness
		new_board.position.x = randi_range(-boundary, boundary)
		new_board.position.z = randi_range(-boundary, boundary)
		new_board.position.y = board_thickness
		
		var new_vector = Vector3(randf_range(-1.0, 1.0), randf_range(0.05, 0.25), randf_range(-1.0, 1.0)).normalized()
		var speed = index/5.0 + 3
		new_board.constant_linear_velocity = new_vector * speed


func get_boards():
	
	return find_children("*", "AnimatableBody3D", true, false)
	

