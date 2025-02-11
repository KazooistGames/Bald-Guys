extends Node3D

const Humanoid_Prefab = preload("res://Scenes/humanoid/humanoid.tscn")

const SessionState = {
	Hub = 0,
	Round = 1,
}

@export var Client_Screennames = {}

@export var State = SessionState.Hub

@export var Commissioned = false

@export var Humanoids = []

@export var Level : Node3D = null

@export var Game : Node3D = null

@onready var HUD = $HUD

@onready var Hub = $Hub

@onready var humanoidSpawner = $HumanoidSpawner
@onready var levelSpawner = $LevelSpawner
@onready var gameSpawner = $GameSpawner

signal Created_Player_Humanoid

signal Destroying_Player_Humanoid

signal Started_Round

signal Ended_Round


func _ready():
	
	humanoidSpawner.spawned.connect(signal_to_handoff_player_humanoid)
	humanoidSpawner.despawned.connect( func (node): HUD.remove_nameplate(str(node.name)))
	gameSpawner.spawned.connect(handle_new_game)
	levelSpawner.spawned.connect(handle_new_level)
	
	if is_multiplayer_authority():
		Commission_Next_Round()
		rpc_move_to_hub.rpc()
		create_player_humanoid(1)
		Commissioned = true


func _process(_delta):
	
	Humanoids = get_tree().get_nodes_in_group("humanoids")
	
	for humanoid in Humanoids:
		var peer_id = humanoid.get_multiplayer_authority()
		
		if Client_Screennames.has(peer_id):
			var head_position = humanoid.position + humanoid.head_position() + Vector3.UP * 0.25
			var screenname = Client_Screennames[peer_id]
			HUD.update_nameplate(humanoid.name, head_position, screenname)
			
		if not Level.node_is_in_bounds(humanoid):
			
			spawn_player(Level, humanoid)
				

func _unhandled_key_input(event):
	
	if not is_multiplayer_authority():
		pass
			
	elif event.is_action_pressed("Toggle"):
			
		if State != SessionState.Hub:
			rpc_move_to_hub.rpc()
			
		elif State != SessionState.Round:
			rpc_move_to_level.rpc()	


func handle_new_level(new_level):
	
	if Level != null:
		Level.queue_free()
		
	Level = new_level
	
	
func handle_new_game(new_game):
	
	if Game != null:
		Game.queue_free()
	
	Game = new_game


func Finished_Round(winner):
	
	HUD.set_psa.rpc("Winner: " + winner, -1)
	rpc_move_to_hub.rpc()
	Commission_Next_Round()


func spawn_player(parent, humanoid):
	
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
	new_peer_humanoid.set_multiplayer_authority(peer_id)
	
	return new_peer_humanoid


func destroy_player_humanoid(peer_id):
	
	var playerHumanoid = get_node_or_null(str(peer_id))
	Destroying_Player_Humanoid.emit(playerHumanoid)
	
	if playerHumanoid:
		Humanoids.erase(playerHumanoid)
		playerHumanoid.queue_free()		
		HUD.remove_nameplate(str(peer_id))


func signal_to_handoff_player_humanoid(node):
	
	Created_Player_Humanoid.emit(node)
	HUD.add_nameplate(str(node.name), str(node.name))
	

@rpc("call_local", "authority", "reliable")
func rpc_move_to_hub():
	
	State = SessionState.Hub
	
	for humanoid in Humanoids:
		spawn_player(Hub, humanoid)	
	
	Ended_Round.emit()	
	
		
@rpc("call_local", "authority", "reliable")
func rpc_move_to_level():
	
	State = SessionState.Round
	
	for humanoid in Humanoids:
		spawn_player(Level, humanoid)
		
	Started_Round.emit()


@rpc("call_local", "authority", "reliable")
func respawn_node(node_path, spawn_position):
	
	var node = get_node(node_path)
	
	if node != null:
		node.position = spawn_position
	

func Commission_Next_Round():
	
	var unique_round_id = randi_range(0, 0)
	var level_prefab_path = ""
	var game_prefab_path = ""
	
	match unique_round_id:
		0:
			level_prefab_path = "res://Scenes/levels/Procedural_Level.tscn"
			game_prefab_path = "res://Scenes/games/Wig_FFA/Wig_FFA.tscn"
	
	if level_prefab_path != ""	and game_prefab_path != "":
		load_level(level_prefab_path)
		load_game(game_prefab_path)
	

func load_level(path):
	
	var prefab = load(path)
	
	if prefab == null:
		return
		
	if Level != null:
		Level.queue_free()
		
	Level = prefab.instantiate()
	add_child(Level, true)
	print("Level commissioned: ", Level)
	

func load_game(path):
	
	var prefab = load(path)
	
	if prefab == null:
		return
		
	if Game != null:
		Game.queue_free()
		
	Game = prefab.instantiate()
	add_child(Game, true)
	print("Game commissioned: ", Game)
	
	
func local_screenname():
	
	var local_id = int(str(multiplayer.get_unique_id()))
	
	if Client_Screennames.has(local_id):
		return Client_Screennames[local_id]
			

	
