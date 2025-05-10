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
@export var Active_Game : Node3D = null
@export var Games : Array = []
@export var Round : int = 0

@export var map_size = 0

@onready var SEED = hash(randi())

@onready var Level : Node3D = $Procedural_Level
@onready var HUD = $HUD

@onready var humanoidSpawner = $HumanoidSpawner

@onready var raycast = $RayCast3D

@onready var pinger = $PingTimer
@onready var unlagger = $LagCompensator

signal Created_Humanoid
signal Destroying_Humanoid

signal Started_Round
signal Ended_Round

var local_ping_ms = 0.0
		
var countDown_timer = 0
var countDown_value = 0

var wigs : Array[Node] = []
var bearers : Array = []


func _ready():
		
	if is_multiplayer_authority():
		add_player(1)
		pinger.timeout.connect(ping_clients)
		pinger.timeout.connect(fix_out_of_bounds)
		print("session SEED: ", SEED)
		rpc_CommissionSession.rpc(SEED)
	
	humanoidSpawner.spawned.connect(handle_new_humanoid)
	humanoidSpawner.despawned.connect( func (node): HUD.remove_nameplate(node.name))


func _process(delta):
		
	Humanoids = get_tree().get_nodes_in_group("humanoids")
	
	for humanoid in Humanoids:
		var peer_id = int(str(humanoid.name))

		if Client_Screennames.has(peer_id):
			var head_position = humanoid.position + humanoid.head_position() + Vector3.UP * 0.25
			var screenname = Client_Screennames[peer_id]
			HUD.update_nameplate(humanoid.name, head_position, screenname, not humanoid.RUNNING)
		
	if Active_Game != null:
		HUD.Scores = Active_Game.Scores
		HUD.Goal = Active_Game.Goal
		
		if not is_multiplayer_authority():
			return	
			
		if Games.size() >= 1:
			wigs = Games[0].wigs
			bearers = Games[0].bearers

		if Active_Game.State == Active_Game.GameState.starting:	
				
			if countDown_value <= 0:
				Active_Game.rpc_play.rpc()
			
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
			StartRound()
		else:	
			FinishRound()


func FinishRound():
	
	Active_Game.GameOver.disconnect(FinishRound)
	Active_Game.rpc_finish.rpc()
	State = SessionState.Intermission	
	Ended_Round.emit()	
	

func add_player(peer_id):
	
	if not is_multiplayer_authority():
		return
	
	print(str(peer_id) + " joined")
	unlagger.CLIENT_PINGS[peer_id] = 0
	
	var new_peer_humanoid = Humanoid_Prefab.instantiate()
	new_peer_humanoid.name = str(peer_id)
	Humanoids.append(new_peer_humanoid)
	add_child(new_peer_humanoid)
	
	rpc_respawn_player.rpc(new_peer_humanoid.get_path())

	HUD.add_nameplate(new_peer_humanoid.name, new_peer_humanoid.name)
	new_peer_humanoid.ragdoll_change.connect(update_nameplate_for_ragdoll)
	Created_Humanoid.emit(new_peer_humanoid)
	
	rpc_CommissionSession.rpc_id(peer_id, SEED)
	Level.init_for_new_client(peer_id)
	
	for game in Games:	
			
		if game.State == game.GameState.reset:
			game.rpc_reset.rpc_id(peer_id)
		elif game.State == game.GameState.starting:
			game.rpc_start.rpc_id(peer_id)
		elif game.State == game.GameState.playing:
			game.rpc_play.rpc_id(peer_id)
		elif game.State == game.GameState.finished:
			game.rpc_finish.rpc_id(peer_id)
			
		game.handle_player_joining(peer_id)
	
	return new_peer_humanoid


func handle_new_humanoid(new_humanoid):
	
	new_humanoid.ragdoll_change.connect(update_nameplate_for_ragdoll)
	HUD.add_nameplate(new_humanoid.name, new_humanoid.name)
	

func remove_player(peer_id):
	
	print(str(peer_id) + " left")
	Client_Screennames.erase(peer_id)
	var players_humanoid = get_node_or_null(str(peer_id))
	
	if players_humanoid:
		Destroying_Humanoid.emit(players_humanoid.get_path())
		
		for game in Games:
			game.handle_player_leaving(peer_id)
			
		Humanoids.erase(players_humanoid)
		HUD.remove_nameplate(str(peer_id))
		players_humanoid.ragdoll_change.disconnect(update_nameplate_for_ragdoll)
		players_humanoid.queue_free()	
			

@rpc("authority", "call_local", "reliable")
func rpc_respawn_player(humanoid_path):
		
	var humanoid = get_node(humanoid_path)		
	humanoid.unragdoll(false)
	humanoid.linear_velocity = Vector3.ZERO
	var spawn_position = get_random_spawn(Level)
	humanoid.position = spawn_position


func get_random_spawn(parent):
	
	var all_spawns = get_tree().get_nodes_in_group("spawns")
	var valid_spawns = []
	
	for spawn in all_spawns:
		
		if spawn.is_ancestor_of(parent):
			valid_spawns.append(spawn)
		
		elif spawn.find_parent(parent.name):
			valid_spawns.append(spawn)
	
	return valid_spawns.pick_random().global_position
	
	
@rpc("call_local", "authority", "reliable")
func rpc_CommissionSession(Seed):
	
	var rng = RandomNumberGenerator.new()
	rng.seed = Seed
	var unique_round_id = rng.randi_range(0, 0)
	
	match unique_round_id:
		0:
			load_game("res://Scenes/session/games/Wig_FFA/Wig_FFA.tscn")			
			load_game("res://Scenes/session/games/Wig_KOTH/Wig_KOTH.tscn")
			
	Commissioned = true
	
	
func StartRound():
	
	countDown_timer = 0
	countDown_value = 5
	Active_Game = Games[Round]
	Active_Game.GameOver.connect(FinishRound)
	State = SessionState.Round	
	HUD.set_psa.rpc(countDown_value)	
	Active_Game.rpc_start.rpc()
	Started_Round.emit()
	Round += 1
	
		
var last_prefab
func load_game(path):
	
	var prefab = load(path)
	var return_val
	
	if prefab == null:	
		print("Could not load game at path: ", path)
		return_val = null
		
	elif last_prefab == prefab:	
		print("Duplicating round of ", prefab)	
		Games.append(Games.back())
		return_val = Games.back()
		
	else:
		print("Commissioning a round of ", prefab)
		var new_game = prefab.instantiate()
		add_child(new_game, true)	
		Games.append(new_game)
		return_val = new_game
		
	last_prefab = prefab
	return return_val
			
	  
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
	
	
func update_nameplate_for_ragdoll(ragdoll_state, node):
	
	if not node.is_in_group("humanoids"):
		pass
		
	elif ragdoll_state:
		HUD.modify_nameplate(node.name, "theme_override_colors/font_color", Color.GRAY)
		HUD.modify_nameplate(node.name, "theme_override_font_sizes/font_size", 16)
	else:
		HUD.modify_nameplate(node.name, "theme_override_colors/font_color", Color.WHITE)
		HUD.modify_nameplate(node.name, "theme_override_font_sizes/font_size", 20)


func fix_out_of_bounds():
	
	for humanoid in Humanoids:
		
		if not node_is_in_bounds(humanoid):		
			rpc_respawn_player.rpc(humanoid.get_path())
			

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


func local_screenname():
	
	var local_id = int(str(multiplayer.get_unique_id()))
	
	if Client_Screennames.has(local_id):
		return Client_Screennames[local_id]
	
	
func local_humanoid() -> Node3D:
	
	if not multiplayer.has_multiplayer_peer():
		return null
	
	for humanoid in Humanoids:
		
		if humanoid.name == str(int(multiplayer.get_unique_id())):
			return humanoid
		
	return null


func get_humanoids_screenname(humanoid : Node3D) -> String:
	
	if humanoid == null:
		return ''	
		
	elif Client_Screennames.has(int(str(humanoid.name))):
		return Client_Screennames[int(str(humanoid.name))]
		
	else:
		return ''
