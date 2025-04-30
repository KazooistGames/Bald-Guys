extends Node3D

const prefab = preload("res://Scenes/geometry/hoverboard/hoverboard.tscn")

const board_thickness = 0.5
const INTRODUCTION_SPEED = 8.0
const RETREAT_SPEED = 8.0

enum Configuration 
{
	inert = 0,
	introducing = 1,
	retreating = 2,
	bouncing = 3
}
@export var configuration = Configuration.introducing

@export var boards : Array[Node] = []
@export var map_size = 50

@onready var rng = RandomNumberGenerator.new()
@onready var unlagger = $LagCompensator

var sync_cooldown_progress = 0.0
var sync_cooldown_rate = 1.0
var all_boards_in_position  = false

signal finished_introducing()
signal finished_retreating()
signal bounced(board : Node3D)
signal constrained(board : Node3D)


func _physics_process(delta):
	
	sync_cooldown_progress += delta * sync_cooldown_rate
	delta *= unlagger.delta_scalar(delta)
	
	if not multiplayer.has_multiplayer_peer():
		pass
		
	elif is_multiplayer_authority() and sync_cooldown_progress >= 1.0:
		synchronize_all_peers()
	
	if configuration == Configuration.inert or boards.size() == 0:
		return
		
	all_boards_in_position = true
	
	for board in boards:
		
		if configuration == Configuration.introducing:
			var lower_lim = board.lower_limits.y + board.girth / 2.0
			var upper_lim = board.upper_limits.y - board.girth / 2.0
			var clamped_target = upper_lim #clampf(map_size/2.0, lower_lim, upper_lim)
			
			if board.position.y > clamped_target:
				all_boards_in_position = false
				
			elif board.status != 0:
				board.status = 0
				
			elif board.throttle > 0:
				all_boards_in_position = false
				
			else:
				board.disable_depenetration = false
				
		elif configuration == Configuration.retreating:
			
			if board.position.y > -board_thickness:
				all_boards_in_position = false
				
			elif board.status != 0:
				board.status = 0
				
			elif board.throttle > 0:
				all_boards_in_position = false

	if not all_boards_in_position:
		pass	
		
	elif configuration == Configuration.introducing:
		finished_introducing.emit()		
		
	elif configuration == Configuration.retreating:
		finished_retreating.emit()
				
		
@rpc("call_local", "reliable")
func create_boards(count, size, speed, height_limits, new_seed = null):
	
	if new_seed != null:
		rng.seed = new_seed
	
	for index in range(count): #create hovering platforms
		var new_board = spawn_board(size)
		var extents = map_size / 2.0
		new_board.lower_limits = Vector3(-extents, height_limits.x, -extents)
		new_board.upper_limits = Vector3(extents, height_limits.y, extents)
		new_board.speed = speed
	

func spawn_board(size):

	var new_board = prefab.instantiate()
	add_child(new_board, true)		
	new_board.size = size
	var boundary = map_size / 2.0 - new_board.size
	new_board.position.x = rng.randi_range(-boundary, boundary)
	new_board.position.z = rng.randi_range(-boundary, boundary)
	new_board.position.y = map_size + randi_range(3, 8)
	new_board.disable_bounce = configuration != Configuration.bouncing
	new_board.disable_constrain = configuration != Configuration.bouncing
	new_board.disable_depenetration = configuration != Configuration.bouncing
	new_board.girth = 1.0
	
	if configuration == Configuration.bouncing:
		new_board.status = 1
		var random_vector = Vector3.ZERO
		random_vector.x = rng.randf_range(-1.0, 1.0)
		random_vector.y = rng.randf_range(0.05, 0.25)
		random_vector.z = rng.randf_range(-1.0, 1.0)
		new_board.trajectory = random_vector.normalized()
		
	elif configuration == Configuration.introducing:
		new_board.trajectory = Vector3.DOWN
		new_board.status = 2
		new_board.external_speed = INTRODUCTION_SPEED
		
	elif configuration == Configuration.retreating:
		new_board.trajectory = Vector3.DOWN
		new_board.status = 2
		new_board.external_speed = RETREAT_SPEED
		
	elif configuration == Configuration.inert:
		new_board.status = 0
		
	boards.append(new_board)
	return new_board


@rpc("call_local", "reliable")
func introduce_boards():
	
	if configuration != Configuration.introducing:
		configuration = Configuration.introducing
		all_boards_in_position = false
		unlagger.reset()
		
		for board in boards:
			board.collider.disabled = false
			board.trajectory = Vector3.DOWN
			board.external_speed = INTRODUCTION_SPEED
			board.status = 2
			board.disable_bounce = true
			board.disable_constrain = true
		
		
@rpc("call_local", "reliable")	
func retreat_boards():
	
	if configuration != Configuration.retreating:
		configuration = Configuration.retreating
		all_boards_in_position = false
		unlagger.reset()
		
		for board in boards:
			board.trajectory = Vector3.DOWN
			board.external_speed = RETREAT_SPEED
			board.status = 2
			board.disable_bounce = true
			board.disable_constrain = true
			board.disable_depenetration = true
		
		
@rpc("call_local", "reliable")	
func bounce_boards():
	
	if configuration != Configuration.bouncing:
		configuration = Configuration.bouncing
		unlagger.reset()	
		
		for board in boards:
			var random_vector = Vector3.ZERO
			random_vector.x = rng.randf_range(-1.0, 1.0)
			random_vector.y = rng.randf_range(0.05, 0.25)
			random_vector.z = rng.randf_range(-1.0, 1.0)
			board.trajectory = random_vector.normalized()
			board.status = 1
			board.disable_bounce = false
			board.disable_constrain = false
			board.disable_depenetration = false


@rpc("call_local", "reliable")	
func stop_boards():
	
	if configuration != Configuration.inert:
		configuration = Configuration.inert
		unlagger.reset()	
		
		for board in boards:
			board.status = 0			

func get_boards():
	
	return find_children("*", "AnimatableBody3D", true, false)
	
	
@rpc("call_local", "reliable")
func clear_boards():
	
	boards = get_boards()
	
	for board in boards:
		board.queue_free()
			
	boards.clear()	
	

func synchronize_all_peers():

	if is_multiplayer_authority():
		var board_positions : PackedVector3Array = []
		var board_trajectories : PackedVector3Array = []
		board_positions.resize(boards.size())
		board_trajectories.resize(boards.size())
		
		for index in range(boards.size()):
			board_positions[index] = boards[index].position
			board_trajectories[index] = boards[index].trajectory
			
		sync_board_positions.rpc(board_positions, board_trajectories)
		sync_cooldown_progress = 0.0
		
		
@rpc("call_remote", "authority", "reliable")	
func sync_board_positions(server_positions : PackedVector3Array, server_trajectories : PackedVector3Array):
	
	for index in range(boards.size()-1):
		boards[index].position = server_positions[index] + unlagger.SERVER_PING / 2000.0 * server_trajectories[index]
		boards[index].trajectory = server_trajectories[index]
	unlagger.reset()

