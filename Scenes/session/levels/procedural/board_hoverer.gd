extends Node3D

const prefab = preload("res://Scenes/geometry/mesa/mesa.tscn")
const sync_prefab = preload("res://Scenes/components/transform_sync/transform_sync.tscn")

const board_thickness = 0.5
@export var map_size = 50

enum Configuration 
{
	inert = 0,
	introducing = 1,
	retreating = 2,
	bouncing = 3
}
@export var configuration = Configuration.introducing

@export var boards = []
@export var board_trajectories = []
@export var height_bounds = []

@onready var rng = RandomNumberGenerator.new()
@onready var sync = $CustomSync
@onready var unlagger = $LagCompensator

var sync_cooldown_progress = 0.0
var sync_cooldown_rate = 1.0

var in_position = false

var introduction_height = 10.0
var introduction_speed = 10.0
var retreat_speed = 5.0

var trajectory_scale = 0.0

signal finished_introducing()
signal finished_retreating()

signal bounced(board : Node3D)
signal constrained(board : Node3D)


func _ready():
	
	if is_multiplayer_authority():
		sync.get_net_var_delegate = get_net_vars
	

func _physics_process(delta):
	
	sync_cooldown_progress += delta * sync_cooldown_rate
	
	if not multiplayer.has_multiplayer_peer():
		pass
	elif is_multiplayer_authority() and sync_cooldown_progress >= 1.0:
		synchronize_all_peers()
	
	delta *= unlagger.delta_scalar(delta)
	
	if configuration == Configuration.inert:
		return
	
	in_position = true
	
	for index in range(board_trajectories.size()): #move hover mesas	

		if index >= boards.size() or index >= height_bounds.size():
			return
		
		var board = boards[index]
		var height_lims = height_bounds[index]
		
		match configuration:
			
			Configuration.introducing:
				
				var clamped_target = clampf(introduction_height, height_lims.x + board_thickness, height_lims.y - board_thickness)
				
				if board.position.y != clamped_target:
					in_position = false
					board.position.y = move_toward(board.position.y, clamped_target, introduction_speed * delta)
				
			Configuration.retreating:
				
				if board.position.y != -board_thickness:
					in_position = false
					board.position.y = move_toward(board.position.y, -board_thickness, retreat_speed * delta)
				
			Configuration.bouncing:
				
				if trajectory_scale != 1.0:
					trajectory_scale = move_toward(trajectory_scale, 1.0, delta / 10.0)
				
				board.position += board_trajectories[index] * delta * pow(trajectory_scale, 1.5)
				var trajectory = board_trajectories[index]
				trajectory = bounce_geometry(board, trajectory) 
				board_trajectories[index] = constrain_geometry(board, trajectory, height_lims)	
			
		if not in_position:
			pass	
		elif configuration == Configuration.introducing:
			finished_introducing.emit()		
		elif configuration == Configuration.retreating:
			finished_retreating.emit()

		
func bounce_geometry(geometry, trajectory):
	
	var starting_trajectory = trajectory
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
	
	if starting_trajectory != trajectory:
		bounced.emit(geometry)
	
	return trajectory
	

func constrain_geometry(geometry, trajectory, height_limits):
	
	var starting_trajectory = trajectory
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
		
	if starting_trajectory != trajectory:
		constrained.emit(geometry)
		
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
	new_board.position.y = map_size + randi_range(1, 5)
	var new_vector = Vector3.ZERO
	new_vector.x = rng.randf_range(-1.0, 1.0)
	new_vector.y = rng.randf_range(0.05, 0.25)
	new_vector.z = rng.randf_range(-1.0, 1.0)
	boards.append(new_board)
	
	return new_vector.normalized()


@rpc("call_local", "reliable")
func introduce_boards(stop_height = 10.0):
	
	if configuration != Configuration.introducing:
		introduction_height = stop_height
		configuration = Configuration.introducing
		in_position = false
		unlagger.reset()
		
		
@rpc("call_local", "reliable")	
func retreat_boards():
	
	if configuration != Configuration.retreating:
		configuration = Configuration.retreating
		in_position = false
		unlagger.reset()
		
		
@rpc("call_local", "reliable")	
func bounce_boards():
	
	if configuration != Configuration.bouncing:
		configuration = Configuration.bouncing
		trajectory_scale = 0.0
		unlagger.reset()	
		

func get_boards():
	
	return find_children("*", "AnimatableBody3D", true, false)
	
	
@rpc("call_local", "reliable")
func clear_boards():
	
	for board in boards:
		board.queue_free()
			
	boards.clear()	
	board_trajectories.clear()
	height_bounds.clear()	
	

func synchronize_all_peers():

	if is_multiplayer_authority():
		var board_positions : PackedVector3Array = []
		board_positions.resize(boards.size())
		
		var trajectories : PackedVector3Array = []
		trajectories.resize(boards.size())
		
		for index in range(boards.size()):
			board_positions[index] = boards[index].position
			trajectories[index] = board_trajectories[index]
		
		sync_board_positions.rpc(board_positions, trajectories)
		sync_cooldown_progress = 0.0
		
		
@rpc("call_remote", "authority", "reliable")	
func sync_board_positions(server_positions : PackedVector3Array, server_trajectories : PackedVector3Array):
	
	for index in range(boards.size()-1):
		boards[index].position = server_positions[index]
		board_trajectories[index] = server_trajectories[index]
		
	unlagger.reset()

		
func get_net_vars():
	
	var net_vars = {}
	net_vars["board_trajectories"] = board_trajectories
	net_vars["height_bounds"] = height_bounds
	return net_vars
