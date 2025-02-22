extends Node3D

const Humanoid_Prefab = preload("res://Scenes/humanoid/humanoid.tscn")

const SessionState = {
	Lobby = 0,
	Round = 1,
}

@export var Client_Screennames = {}
@export var State = SessionState.Lobby
@export var Commissioned = false
@export var Humanoids = []

@export var Level : Node3D = null

@export var Game : Node3D = null

@onready var HUD = $HUD

@onready var Lobby = $Lobby

@onready var humanoidSpawner = $HumanoidSpawner
@onready var levelSpawner = $LevelSpawner
@onready var gameSpawner = $GameSpawner

@onready var raycast = $RayCast3D

@onready var pinger = $PingTimer
@onready var unlagger = $LagCompensator

signal Created_Player_Humanoid
signal Destroying_Player_Humanoid

signal Started_Round
signal Ended_Round

var local_ping_ms = 0.0
		

func _ready():
		
	pinger.timeout.connect(ping_clients)
	pinger.timeout.connect(fix_out_of_bounds)
	
	humanoidSpawner.spawned.connect(func(node): HUD.add_nameplate(node.name, node.name))
	humanoidSpawner.despawned.connect( func (node): HUD.remove_nameplate(node.name))
	gameSpawner.spawned.connect(handle_new_game)
	levelSpawner.spawned.connect(handle_new_level)
	
	if is_multiplayer_authority():
		Commission_Next_Round()
		rpc_move_to_Lobby.rpc()
		create_player_humanoid(1)
		Commissioned = true


func _process(delta):
	
	unlagger.compensated_delta(delta)
	
	Humanoids = get_tree().get_nodes_in_group("humanoids")
	
	for humanoid in Humanoids:
		var peer_id = int(str(humanoid.name))
		
		if Client_Screennames.has(peer_id):
			var head_position = humanoid.position + humanoid.head_position() + Vector3.UP * 0.25
			var screenname = Client_Screennames[peer_id]
			HUD.update_nameplate(humanoid.name, head_position, screenname)
				

func _unhandled_key_input(event):
	
	if not is_multiplayer_authority():
		pass
			
	elif event.is_action_pressed("Toggle"):
			
		if State != SessionState.Lobby:
			rpc_move_to_Lobby.rpc()
			
		elif State != SessionState.Round:
			rpc_move_to_level.rpc()	


func fix_out_of_bounds():
	
	for humanoid in Humanoids:
		
		if not node_is_in_bounds(humanoid):		
			spawn_player(Level, humanoid)
			

func node_is_in_bounds(node):
	
	raycast.global_position = node.global_position #move raycast to node position
	raycast.target_position = Vector3.UP * 100 #shoot it up to the ceiling
	raycast.force_raycast_update()	
	var hit_the_ceiling = raycast.is_colliding()	
	
	raycast.target_position = Vector3.DOWN * 100 #shoot it to the floor
	raycast.force_raycast_update()	
	var hit_the_floor = raycast.is_colliding()

	return hit_the_ceiling or hit_the_floor #node is considered inside level if it hits one
	

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
	rpc_move_to_Lobby.rpc()
	Commission_Next_Round()


func spawn_player(parent, humanoid):
		
	humanoid.unragdoll(false)
	humanoid.linear_velocity = Vector3.ZERO
	var spawn_position = get_random_spawn(parent)
	var rid = humanoid.get_rid()
	var new_transform = Transform3D.IDENTITY.translated(spawn_position)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, new_transform)
	humanoid.find_child("*lowerBody*").position = Vector3.UP


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
	
	var random_spawn_position = get_random_spawn(Lobby)
	respawn_node.rpc(new_peer_humanoid.get_path(), random_spawn_position)

	HUD.add_nameplate(new_peer_humanoid.name, new_peer_humanoid.name)
	new_peer_humanoid.ragdoll_change.connect(update_nameplate_for_ragdoll)
	Created_Player_Humanoid.emit(new_peer_humanoid)
	
	return new_peer_humanoid


func destroy_player_humanoid(peer_id):
	
	var player_Humanoid = get_node_or_null(str(peer_id))
	
	if player_Humanoid:
		Destroying_Player_Humanoid.emit(player_Humanoid)
		Humanoids.erase(player_Humanoid)
		HUD.remove_nameplate(str(peer_id))
		player_Humanoid.ragdoll_change.disconnect(update_nameplate_for_ragdoll)
		player_Humanoid.queue_free()		


@rpc("call_local", "authority", "reliable")
func rpc_move_to_Lobby():
	
	State = SessionState.Lobby
	
	for humanoid in Humanoids:
		spawn_player(Lobby, humanoid)	
	
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
			level_prefab_path = "res://Scenes/session/levels/Procedural_Level.tscn"
			game_prefab_path = "res://Scenes/session/games/Wig_FFA/Wig_FFA.tscn"
	
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
			
	
@rpc("authority", "call_remote")
func ping(server_time : float):  
	
	if is_multiplayer_authority():
		pass
	else:
		local_ping_ms = (Time.get_unix_time_from_system() - server_time) * 1000.0
		unlagger.GLOBAL_PING = local_ping_ms
		unlagger.reset()
		HUD.set_ping_indicator(local_ping_ms)
		
	  
func ping_clients():
	
	if is_multiplayer_authority():
		var local_server_time = Time.get_unix_time_from_system()
		ping.rpc(local_server_time)
	
	
func update_nameplate_for_ragdoll(new_value, node):
	
	if not node.is_in_group("humanoids"):
		pass
		
	elif new_value:
		HUD.modify_nameplate(node.name, "theme_override_colors/font_color", Color.GRAY)
		HUD.modify_nameplate(node.name, "theme_override_font_sizes/font_size", 12)
	else:
		HUD.modify_nameplate(node.name, "theme_override_colors/font_color", Color.WHITE)
		HUD.modify_nameplate(node.name, "theme_override_font_sizes/font_size", 16)
