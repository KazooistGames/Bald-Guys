extends Node3D

const prefab = preload("res://Scenes/geometry/mesa/mesa.tscn")

const board_thickness = 0.5

const map_size = 50

@export var boards = []
@export var speeds = []


func _physics_process(delta):
	
	boards = get_boards()
	
	for index in range(speeds.size()): #move hover mesas	
		var board = boards[index]
		var intersections = get_collider_intersections(board)

		var xz_bounds = board.size / 2.0
		var y_bounds = board.raycast.target_position.length() / 2.0
		var trajectory = speeds[index]
		
		if intersections == null:
			pass
					
		else:		
			var penetration = intersections[0] - intersections[1] 
			board.position -= penetration
			
			if abs(penetration.y) >= abs(penetration.x) and abs(penetration.y) >= abs(penetration.z):		
				trajectory.y *= -1

			elif abs(penetration.x) >= abs(penetration.z):
				trajectory.x *= -1

			else:
				trajectory.z *= -1		

		if board.position.y > 15:
			trajectory.y = -trajectory.y
			board.position.y = 15
			
		elif board.position.y < 0:
			trajectory.y = -trajectory.y
			board.position.y = 0

		board.position += trajectory * delta
		speeds[index] = trajectory
		
		
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
		return result 
		
		
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
		#new_board.constant_linear_velocity = new_vector * speed
		boards.append(new_board)
		speeds.append(new_vector * speed)


func get_boards():
	
	return find_children("*", "AnimatableBody3D", true, false)
	

func clear_boards():
	
	boards = get_boards()
	
	for board in boards:
		board.queue_free()
			
	boards.clear()	
