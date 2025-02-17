extends Node3D

const prefab = preload("res://Scenes/geometry/mesa/mesa.tscn")

const board_thickness = 0.5

const map_size = 50

@export var boards = []
@export var board_trajectories = []
@export var height_bounds = []

@onready var sync = $CustomSync

@onready var rng = RandomNumberGenerator.new()


func _ready():
	
	if is_multiplayer_authority():
		sync.get_net_var_delegate = get_net_vars


func _physics_process(delta):
	
	for index in range(board_trajectories.size()): #move hover mesas	
		
		if index >= boards.size() or index >= height_bounds.size():
			return
			
		var board = boards[index]
		var height_lims = height_bounds[index]
		board.position += board_trajectories[index] * delta
		var trajectory = bounce_geometry(board, board_trajectories[index])
		board_trajectories[index] = constrain_geometry(board, trajectory, height_lims)	
	
		
func bounce_geometry(geometry, trajectory):
	
	var intersections = get_collider_intersections(geometry, trajectory)
	
	if intersections == null:
		pass
				
	else:		
		var penetration = intersections[0] - intersections[1] 
		geometry.position -= penetration
		
		if abs(penetration.y) >= abs(penetration.x) and abs(penetration.y) >= abs(penetration.z):	
			trajectory.y *= -1.0		
						
		elif abs(penetration.x) >= abs(penetration.z):
			trajectory.x *= -1.0
			
		else:
			trajectory.z *= -1.0	
	
	return trajectory
	

func constrain_geometry(geometry, trajectory, height_limits):
	
	var xz_boundaries = map_size / 2.0
	var girth = board_thickness
	#	X
	if geometry.position.x > xz_boundaries:
		trajectory.x *= -1.0	
		geometry.position.x = xz_boundaries
		
	elif geometry.position.x < -xz_boundaries:
		trajectory.x *= -1.0	
		geometry.position.x = -xz_boundaries
		
	#	Y
	if geometry.position.y >= height_limits.y:
		trajectory.y *= -1.0	
		geometry.position.y = height_limits.y
			
	elif geometry.position.y <= height_limits.x + girth:
		trajectory.y *= -1.0		
		geometry.position.y = height_limits.x + girth
		
	#	Z
	if geometry.position.z > xz_boundaries:
		trajectory.z *= -1.0
		geometry.position.z = xz_boundaries
		
	elif geometry.position.z < -xz_boundaries:
		trajectory.z *= -1.0	
		geometry.position.z = -xz_boundaries
	
	return trajectory
		
		
func get_collider_intersections(body, trajectory):
	
	var physics_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = body.collider.shape
	query.transform = body.collider.global_transform
	query.motion = trajectory
	query.exclude = [body.get_rid(), self.get_parent_node_3d()]
	query.collision_mask = 0b0001
	var result = physics_state.collide_shape(query)
	
	if result.size() > 0:
		return result 
		
		
@rpc("call_local", "reliable")
func create_boards(count, size, speed, height_limits, new_seed):
	
	if new_seed != null:
		rng.seed = new_seed
	
	for index in range(count): #create hovering platforms
		var initial_vector = spawn_board(size)
		board_trajectories.append(initial_vector * speed)
		height_bounds.append(height_limits)


func spawn_board(size):

	var new_board = prefab.instantiate()
	add_child(new_board, true)		
	new_board.size = size
	var boundary = map_size / 2.0 - new_board.size / 2.0
	new_board.bottom_drop = 0.0
	new_board.preference = new_board.Preference.deep
	new_board.raycast_target = Vector3.DOWN * board_thickness
	new_board.position.x = rng.randi_range(-boundary, boundary)
	new_board.position.z = rng.randi_range(-boundary, boundary)
	new_board.position.y = board_thickness
	var new_vector = Vector3.ZERO
	new_vector.x = rng.randf_range(-1.0, 1.0)
	new_vector.y = rng.randf_range(0.05, 0.25)
	new_vector.z = rng.randf_range(-1.0, 1.0)
	boards.append(new_board)
	
	return new_vector.normalized()


func get_boards():
	
	return find_children("*", "AnimatableBody3D", true, false)
	
	
@rpc("call_local", "reliable")
func clear_boards():
	
	for board in boards:
		board.queue_free()
			
	boards.clear()	
	board_trajectories.clear()
	height_bounds.clear()


func get_net_vars():
	
	var net_vars = {}
	net_vars["board_trajectories"] = board_trajectories
	net_vars["height_bounds"] = height_bounds
	return net_vars
