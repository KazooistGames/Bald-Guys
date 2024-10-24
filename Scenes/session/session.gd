extends Node3D

const Humanoid_Prefab = preload("res://Scenes/humanoid/humanoid.tscn")

const SessionState = {
	Hub = 0,
	Level = 1,
}

@export var State = SessionState.Hub

const GameMode = {
	FFA = 0,
}

@export var Mode = GameMode.FFA

@export var Commissioned = false

@export var Humanoids = []

@onready var FFA = $Wig_FFA

@onready var Hub = $Hub

@onready var Level = $Level

@onready var humanoidSpawner = $MultiplayerSpawner

signal Created_Player_Humanoid


func _ready():
	humanoidSpawner.spawned.connect(signal_to_handoff_player_humanoid)


func _unhandled_key_input(event):
	
	if event.is_action_pressed("Toggle"):
		
		if State != SessionState.Level:
			rpc_move_to_level.rpc()	
			
		elif State != SessionState.Hub:
			rpc_move_to_hub.rpc()


func end_game_mode():
	
	rpc_move_to_hub.rpc()

func start_game_mode():
	
	if Mode == GameMode.FFA:
		FFA.rpc_start.rpc()
		FFA.Finished.connect(end_game_mode)
		
		
func reset_game_mode():
	
	if Mode == GameMode.FFA:
		FFA.rpc_reset.rpc()
	

func Commission():
	
	rpc_move_to_hub.rpc()
	create_player_humanoid(1)
	Commissioned = true


func spawn_players(parent):
	
	for humanoid in Humanoids:
		humanoid.unragdoll.rpc()
		respawn_node.rpc(humanoid.get_path(), get_random_spawn(parent))
		

func get_random_spawn(parent):
	
	var all_spawns = get_tree().get_nodes_in_group("spawns")
	var valid_spawns = []
	
	for spawn in all_spawns:
		
		if spawn.is_ancestor_of(parent):
			valid_spawns.append(spawn)
		
		elif spawn.find_parent(parent.name):
			valid_spawns.append(spawn)
	
	return valid_spawns.pick_random().global_position


func create_player_humanoid(peer_id):
	
	var new_peer_humanoid = Humanoid_Prefab.instantiate()
	new_peer_humanoid.name = str(peer_id)
	new_peer_humanoid.position = get_random_spawn(Hub)
	Humanoids.append(new_peer_humanoid)
	add_child(new_peer_humanoid)
	signal_to_handoff_player_humanoid(new_peer_humanoid)
	return new_peer_humanoid
	#Created_Player_Humanoid.emit(new_peer_humanoid.get_path(), peer_id)


func destroy_player_humanoid(peer_id):
	
	var playerHumanoid = get_node_or_null(str(peer_id))
	
	if playerHumanoid:
		Humanoids.erase(playerHumanoid)
		playerHumanoid.queue_free()


func signal_to_handoff_player_humanoid(node):
	
	Created_Player_Humanoid.emit(node)


@rpc("call_local")
func rpc_move_to_hub():
	
	State = SessionState.Hub
	spawn_players(Hub)		
	reset_game_mode()

		
@rpc("call_local")
func rpc_move_to_level():
	
	State = SessionState.Level
	spawn_players(Level)
	start_game_mode()


@rpc("call_local")
func respawn_node(node_path, spawn_position):
	
	var node = get_node(node_path)
	node.velocity = Vector3.ZERO
	node.position = spawn_position
