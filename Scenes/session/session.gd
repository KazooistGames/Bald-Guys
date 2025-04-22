extends Node3D

const Humanoid_Prefab = preload("res://Scenes/humanoid/humanoid.tscn")

const SessionState = {
	Lobby = 0,
	Round = 1,
	Intermission = 2,
}

@export var Client_Screennames : Dictionary = {}
@export var State = SessionState.Lobby
@export var Commissioned = false
@export var Humanoids = []
@export var Game : Node3D = null

@export var map_size = 0

@onready var Level : Node3D = $Procedural_Level
@onready var HUD = $HUD

@onready var humanoidSpawner = $HumanoidSpawner
@onready var gameSpawner = $GameSpawner

@onready var raycast = $RayCast3D

@onready var pinger = $PingTimer
@onready var unlagger = $LagCompensator

signal Created_Player_Humanoid
signal Destroying_Player_Humanoid

signal Started_Round
signal Ended_Round

var local_ping_ms = 0.0
		
var countDown_timer = 0
var countDown_value = 0


func _ready():
		
	if is_multiplayer_authority():
		pinger.timeout.connect(ping_clients)
		pinger.timeout.connect(fix_out_of_bounds)
	
	humanoidSpawner.spawned.connect(handle_new_humanoid)
	humanoidSpawner.despawned.connect( func (node): HUD.remove_nameplate(node.name))
	gameSpawner.spawned.connect(handle_new_game)
	
	if is_multiplayer_authority():
		Commission_Next_Round()
		create_player_humanoid(1)
		Commissioned = true


func _process(delta):
		
	Humanoids = get_tree().get_nodes_in_group("humanoids")
	
	for humanoid in Humanoids:
		var peer_id = int(str(humanoid.name))
		
		if Client_Screennames.has(peer_id):
			var head_position = humanoid.position + humanoid.head_position() + Vector3.UP * 0.25
			var screenname = Client_Screennames[peer_id]
			HUD.update_nameplate(humanoid.name, head_position, screenname)
				
	if Game == null:
		pass
		
	else:
		
		HUD.Scores = Game.Scores
		HUD.Goal = Game.Goal
		
		if Game.State == Game.GameState.starting:	
				
			if countDown_value <= 0:
				Game.rpc_play.rpc()
			
			elif countDown_timer > 1:
				countDown_timer = 0
				countDown_value -= 1
				HUD.set_psa.rpc(str(countDown_value))
			
			else:
				countDown_timer += delta
		

func _unhandled_key_input(event):
	
	if not is_multiplayer_authority():
		pass
			
	elif event.is_action_pressed("Toggle"):
			
		if State != SessionState.Round:
			State = SessionState.Round	
			countDown_value = 20
			HUD.set_psa.rpc(str(countDown_value))		
			Started_Round.emit()
			
		else:	
			State = SessionState.Intermission			
			Ended_Round.emit()


func fix_out_of_bounds():
	
	for humanoid in Humanoids:
		
		if not node_is_in_bounds(humanoid):		
			spawn_player.rpc(Level.get_path(), humanoid.get_path())
			

func node_is_in_bounds(node):
	
	if not Level:
		return true
	
	raycast.global_position = node.global_position + Vector3.DOWN #move raycast to node position
	raycast.target_position = Vector3.UP * Level.map_size * 5 #shoot it up to the ceiling
	raycast.force_raycast_update()	
	var hit_the_ceiling = raycast.is_colliding()	
	
	raycast.global_position = node.global_position + Vector3.UP
	raycast.target_position = Vector3.DOWN * Level.map_size * 5 #shoot it to the floor
	raycast.force_raycast_update()	
	var hit_the_floor = raycast.is_colliding()

	return hit_the_ceiling and hit_the_floor #node is considered inside level if it hits one
	

func handle_new_level(new_level):
	
	if Level != null:
		Level.queue_free()
		
	Level = new_level
	
	
func handle_new_game(new_game):
	
	if Game != null:
		Game.queue_free()
	
	Game = new_game


func Finished_Round(winner):
	
	HUD.set_psa.rpc("Winner:\n\n" + winner, -1)
	Ended_Round.emit()	
	Commission_Next_Round()


@rpc("authority", "call_local")
func spawn_player(parent_path, humanoid_path):
		
	var parent = get_node(parent_path)
	var humanoid = get_node(humanoid_path)	
		
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
	
	unlagger.CLIENT_PINGS[peer_id] = 0
	
	var new_peer_humanoid = Humanoid_Prefab.instantiate()
	new_peer_humanoid.name = str(peer_id)
	Humanoids.append(new_peer_humanoid)
	add_child(new_peer_humanoid)
	
	var random_spawn_position = get_random_spawn(Level)
	respawn_node.rpc(new_peer_humanoid.get_path(), random_spawn_position)

	HUD.add_nameplate(new_peer_humanoid.name, new_peer_humanoid.name)
	new_peer_humanoid.ragdoll_change.connect(update_nameplate_for_ragdoll)
	Created_Player_Humanoid.emit(new_peer_humanoid)
	
	return new_peer_humanoid


func handle_new_humanoid(new_humanoid):
	
	new_humanoid.ragdoll_change.connect(update_nameplate_for_ragdoll)
	HUD.add_nameplate(new_humanoid.name, new_humanoid.name)
	

func destroy_player_humanoid(peer_id):
	
	var player_Humanoid = get_node_or_null(str(peer_id))
	
	if player_Humanoid:
		Destroying_Player_Humanoid.emit(player_Humanoid)
		Humanoids.erase(player_Humanoid)
		HUD.remove_nameplate(str(peer_id))
		player_Humanoid.ragdoll_change.disconnect(update_nameplate_for_ragdoll)
		player_Humanoid.queue_free()		


func move_to_level():
	
	State = SessionState.Round
	
	for humanoid in Humanoids:
		spawn_player.rpc(Level.get_path(), humanoid.get_path())
		
	Started_Round.emit()


@rpc("call_local", "authority", "reliable")
func respawn_node(node_path, spawn_position):
	
	var node = get_node(node_path)
	
	if node != null:
		node.position = spawn_position
	

func Commission_Next_Round():
	
	var unique_round_id = randi_range(1, 1)
	var game_prefab_path = ""
	
	match unique_round_id:
		0:
			game_prefab_path = "res://Scenes/session/games/Wig_FFA/Wig_FFA.tscn"
		1:
			game_prefab_path = "res://Scenes/session/games/Wig_KOTH/Wig_KOTH.tscn"
			
	if game_prefab_path != "":
		load_game(game_prefab_path)
	

func load_game(path):
	
	var prefab = load(path)
	
	if prefab == null:
		return
		
	if Game != null:
		Game.queue_free()
		
	Game = prefab.instantiate()
	add_child(Game, true)
	print("Commissioned a round of ", Game)
	
	
func local_screenname():
	
	var local_id = int(str(multiplayer.get_unique_id()))
	
	if Client_Screennames.has(local_id):
		return Client_Screennames[local_id]
		

func get_humanoids_screenname(humanoid : Node3D) -> String:
	
	if humanoid == null:
		return ''	
		
	elif Client_Screennames.has(int(str(humanoid.name))):
		return Client_Screennames[int(str(humanoid.name))]
		
	else:
		return ''
		
	  
func ping_clients():
	
	var local_server_time = Time.get_unix_time_from_system()
	ping.rpc(local_server_time)
				
	
@rpc("any_peer", "call_remote")
func ping(passthrough_time : float):  

	var sender_id = multiplayer.get_remote_sender_id()
	pong.rpc_id(sender_id, passthrough_time)
	
	if not is_multiplayer_authority():
		var local_client_time = Time.get_unix_time_from_system()
		ping.rpc_id(get_multiplayer_authority(), local_client_time)
		
		
@rpc("any_peer", "call_remote")
func pong(ping_timestamp : float): #responding RPC call that passes back initial timestamp to original pinger

	var local_timestamp = Time.get_unix_time_from_system()
	var ping_ms = (local_timestamp - ping_timestamp) * 1000.0 / 2.0
	
	if is_multiplayer_authority():
		unlagger.CLIENT_PINGS[multiplayer.get_remote_sender_id()] = ping_ms
		
	else:
		unlagger.SERVER_PING = ping_ms
		HUD.set_ping_indicator(ping_ms)	
		unlagger.reset()
	
	
func update_nameplate_for_ragdoll(new_value, node):
	
	if not node.is_in_group("humanoids"):
		pass
		
	elif new_value:
		HUD.modify_nameplate(node.name, "theme_override_colors/font_color", Color.GRAY)
		HUD.modify_nameplate(node.name, "theme_override_font_sizes/font_size", 16)
	else:
		HUD.modify_nameplate(node.name, "theme_override_colors/font_color", Color.WHITE)
		HUD.modify_nameplate(node.name, "theme_override_font_sizes/font_size", 20)
