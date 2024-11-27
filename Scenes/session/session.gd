extends Node3D

const Humanoid_Prefab = preload("res://Scenes/humanoid/humanoid.tscn")

const SessionState = {
	Hub = 0,
	Round = 1,
}

@export var State = SessionState.Hub

@export var Commissioned = false

@export var Humanoids = []

@export var Level : Node3D = null

@export var Game : Node3D = null

@onready var Hub = $Hub

@onready var humanoidSpawner = $HumanoidSpawner

@onready var levelSpawner = $LevelSpawner

@onready var gameSpawner = $GameSpawner

signal Created_Player_Humanoid

signal Started_Round

signal Ended_Round


func _ready():
	humanoidSpawner.spawned.connect(signal_to_handoff_player_humanoid)
	gameSpawner.spawned.connect(handle_new_game)
	levelSpawner.spawned.connect(handle_new_level)

func _process(_delta):
	Humanoids = get_tree().get_nodes_in_group("humanoids")


func _unhandled_key_input(event):
	
	if event.is_action_pressed("Toggle"):
		
		if not is_multiplayer_authority():
			pass
			
		elif State != SessionState.Hub:
			rpc_move_to_hub.rpc()
			
		elif State != SessionState.Round:
			rpc_move_to_level.rpc()	

func handle_new_level(new_level):
	Level = new_level
	
func handle_new_game(new_game):
	Game = new_game


func Finished_Level():
	
	rpc_move_to_hub.rpc()


func spawn_players(parent):
	
	for humanoid in Humanoids:
		humanoid.unragdoll.rpc()
		humanoid.linear_velocity = Vector3.ZERO
		var spawn_position = get_random_spawn(parent)
		var rid = humanoid.get_rid()
		var new_transform = Transform3D.IDENTITY.translated(spawn_position)
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, new_transform)


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
	
	Humanoids.append(new_peer_humanoid)
	
	add_child(new_peer_humanoid)
	
	var random_spawn_position = get_random_spawn(Hub)
	respawn_node.rpc(new_peer_humanoid.get_path(), random_spawn_position)
	
	signal_to_handoff_player_humanoid(new_peer_humanoid)
	return new_peer_humanoid


func destroy_player_humanoid(peer_id):
	
	var playerHumanoid = get_node_or_null(str(peer_id))
	
	if playerHumanoid:
		Humanoids.erase(playerHumanoid)
		playerHumanoid.queue_free()


func signal_to_handoff_player_humanoid(node):
	
	Created_Player_Humanoid.emit(node)


@rpc("call_local", "authority", "reliable")
func rpc_move_to_hub():
	
	State = SessionState.Hub
	spawn_players(Hub)		
	Ended_Round.emit()

		
@rpc("call_local", "authority", "reliable")
func rpc_move_to_level():
	
	State = SessionState.Round
	spawn_players(Level)
	Started_Round.emit()


@rpc("call_local", "authority", "reliable")
func respawn_node(node_path, spawn_position):
	
	var node = get_node(node_path)
	node.position = spawn_position
	

func Commission_Round():
	
	var unique_round_id = randi_range(0, 0)
	var level_prefab_path = ""
	var game_prefab_path = ""
	
	match unique_round_id:
		0:
			level_prefab_path = "res://Scenes/level/Platforms_Level.tscn"
			game_prefab_path = "res://Scenes/games/Wig_FFA/Wig_FFA.tscn"
	
	if level_prefab_path != ""	and game_prefab_path != "":
		load_level(level_prefab_path)
		load_game(game_prefab_path)
	

func load_level(path):
	
	var prefab = load(path)
	
	if prefab != null:
		Level = prefab.instantiate()
		add_child(Level)
	

func load_game(path):
	
	var prefab = load(path)
	
	if prefab != null:
		Game = prefab.instantiate()
		add_child(Game)
		
		
		
		
		
