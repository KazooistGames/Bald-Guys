extends Node3D

const prefab = preload("res://Scenes/geometry/mesa/mesa.tscn")

const board_thickness = 0.5

const map_size = 50

#const upper_limits = Vector3(25, 15, 25)
#
#const lower_limits = Vector3(-25, 0, -25)

@export var boards = []
@export var board_speeds = []
@export var height_bounds = []


func _physics_process(delta):
	
	boards = get_boards()
	
	for index in range(board_speeds.size()): #move hover mesas	
		
		if index >= boards.size():
			return
			
		var board = boards[index]
		var height_lims = height_bounds[index]
		var trajectory = bounce_geometry(board, board_speeds[index])
		trajectory = constrain_geometry(board, trajectory, height_lims)	
		board.position += trajectory * delta
		board_speeds[index] = trajectory
	
		
func bounce_geometry(geometry, trajectory):
	
	var intersections = get_collider_intersections(geometry)

	var xz_bounds = geometry.size / 2.0
	var y_bounds = geometry.raycast.target_position.length() / 2.0
	
	if intersections == null:
		pass
				
	else:		
		var penetration = intersections[0] - intersections[1] 
		geometry.position -= penetration
		
		if abs(penetration.y) >= abs(penetration.x) and abs(penetration.y) >= abs(penetration.z):		
			trajectory.y *= -1

		elif abs(penetration.x) >= abs(penetration.z):
			trajectory.x *= -1

		else:
			trajectory.z *= -1		
	
	return trajectory
	

func constrain_geometry(geometry, trajectory, height_bounds):
	
	var xz_boundaries = map_size / 2.0
	#	X
	if geometry.position.x > xz_boundaries:
		trajectory.x = -trajectory.x
		geometry.position.x = xz_boundaries
		
	elif geometry.position.x < -xz_boundaries:
		trajectory.x = -trajectory.x
		geometry.position.x = -xz_boundaries
		
	#	Y
	if geometry.position.y > height_bounds.y:
		trajectory.y = -trajectory.y
		geometry.position.y = height_bounds.y
			
	elif geometry.position.y < height_bounds.x:
		trajectory.y = -trajectory.y
		geometry.position.y = height_bounds.x
		
	#	Z
	if geometry.position.z > xz_boundaries:
		trajectory.z = -trajectory.z
		geometry.position.z = xz_boundaries
		
	elif geometry.position.z < -xz_boundaries:
		trajectory.z = -trajectory.z
		geometry.position.z = -xz_boundaries
	
	return trajectory
		
		
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
		
		
func spawn_boards(count, size, speed, height_limits):
	
	for index in range(count): #create hovering platforms
		var new_board = prefab.instantiate()
		add_child(new_board, true)		
		new_board.size = size
		var boundary = map_size / 2.0 - new_board.size / 2.0
		new_board.bottom_drop = 0.0
		new_board.preference = new_board.Preference.deep
		new_board.raycast.target_position = Vector3.DOWN * board_thickness
		new_board.position.x = randi_range(-boundary, boundary)
		new_board.position.z = randi_range(-boundary, boundary)
		new_board.position.y = board_thickness
		
		var new_vector = Vector3(randf_range(-1.0, 1.0), randf_range(0.05, 0.25), randf_range(-1.0, 1.0)).normalized()
		boards.append(new_board)
		board_speeds.append(new_vector * speed)
		height_bounds.append(height_limits)


func get_boards():
	
	return find_children("*", "AnimatableBody3D", true, false)
	

func clear_boards():
	
	boards = get_boards()
	
	for board in boards:
		board.queue_free()
			
	boards.clear()	
