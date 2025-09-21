class_name Session extends Node3D

const Humanoid_Prefab : PackedScene = preload("res://Scenes/humanoid/humanoid.tscn")
const DEBUG := false

const SessionState = {
	Lobby = 0,
	Round = 1,
	Reconfiguring = 2,
	Vote = 3,
}

var Client_Screennames : Dictionary = {}
var State = SessionState.Lobby
var Commissioned = false
var Humanoids : Array[Node] = []
var All_Games : Array[Game] = []
var Round : int = 0
var Active_Game : Game

@onready var session_rng = RandomNumberGenerator.new()
@onready var Level : Node3D = $Procedural_Level
@onready var HUD : Hud = $HUD
@onready var humanoidSpawner : MultiplayerSpawner = $HumanoidSpawner
@onready var raycast : RayCast3D = $RayCast3D
@onready var periodic_checks : Node = $PingTimer
@onready var wig_manager : WigManager = $wig_manager

signal Created_Humanoid
signal Destroying_Humanoid
signal Started_Round
signal Ended_Round

var local_ping_ms = 0.0
var countDown_timer = 0
var countDown_value = 0
var game_vote_options : Array[Game] = []


func _ready():
		
	if is_multiplayer_authority():
		periodic_checks.timeout.connect(fix_out_of_bounds)
		add_player(1)
	
	humanoidSpawner.spawned.connect(handle_new_humanoid)
	humanoidSpawner.despawned.connect( func (node): HUD.remove_nameplate(node.name))
	
	var game_nodes = get_tree().get_nodes_in_group("Game")
	
	for node in game_nodes:
		
		if node == null:
			pass
		elif node is Game:
			All_Games.append(node)	


func _process(_delta):
		
	Humanoids = get_tree().get_nodes_in_group("humanoids")
	
	for humanoid in Humanoids:
		var peer_id = int(str(humanoid.name))

		if Client_Screennames.has(peer_id):
			var head_position = humanoid.position + humanoid.head_position() + Vector3.UP * 0.25
			var screenname = Client_Screennames[peer_id]
			#HUD.update_nameplate(humanoid.name, head_position, screenname, not humanoid.RUNNING)
			#HUD.modify_nameplate(humanoid.name, {'visible' : humanoid.RUNNING})
		
	for game : Game in All_Games:
		game.map_size = Level.room.Current_Size


func _physics_process(delta):
	
	if not multiplayer.has_multiplayer_peer():
		pass
		
	elif not is_multiplayer_authority():
		return	
		
	
	if State == SessionState.Lobby:
		HUD.find_child("Progress").visible = false
		
	elif State == SessionState.Vote:
		
		HUD.find_child("Progress").visible = false
		
		if countDown_value <= 0:
			Level.get_vote()
		
		elif countDown_timer > 1:
			countDown_timer = 0
			countDown_value -= 1
			HUD.set_psa.rpc(str(countDown_value), 1.1)
		
		else:
			countDown_timer += delta
			
	elif State == SessionState.Round and Active_Game:
		HUD.Scores = Active_Game.Scores
		HUD.Goal = Active_Game.Goal
	

func _unhandled_key_input(event):
	
	if not is_multiplayer_authority():
		pass
			
	elif event.is_action_pressed("Toggle"):
			
		if State == SessionState.Lobby:
			Try_Start_Session()
			
		elif State == SessionState.Vote:
			#Try_Get_Vote()
			Level.get_vote()
			
		elif State == SessionState.Round:	
			Try_Finish_Round()


func Try_Start_Session():
	
	Try_Vote()
	

func Try_Vote():
	
	if Level.demolished.is_connected(Try_Vote):
		Level.demolished.disconnect(Try_Vote)
	
	game_vote_options = []
	game_vote_options.append(get_eligible_game())
	game_vote_options.append(get_eligible_game())

	Level.vote()
	countDown_timer = 0
	countDown_value = 60
	HUD.set_psa.rpc(str(countDown_value))
	State = SessionState.Vote
	
	if not Level.voted.is_connected(Try_Get_Vote):
		Level.voted.connect(Try_Get_Vote)
		
	if Active_Game:
		Active_Game.rpc_reset.rpc()


func Try_Get_Vote(game_index):
	
	if Level.demolished.is_connected(Level.vote):
		Level.demolished.disconnect(Level.vote)
	
	wig_manager.clear_wigs()
	Active_Game = game_vote_options.pick_random() if game_index == -1 else game_vote_options[game_index]
	Level.generate()
	State = SessionState.Reconfiguring

	if not Level.generated.is_connected(Try_Start_Round):
		Level.generated.connect(Try_Start_Round)


func Try_Start_Round():
	
	Level.generated.disconnect(Try_Start_Round)
	
	if not Active_Game:
		Try_Finish_Round()
		return
		
	Active_Game.rpc_play.rpc()		
	State = SessionState.Round	
	Started_Round.emit()
	
	if not Active_Game.GameOver.is_connected(Try_Finish_Round):
		Active_Game.GameOver.connect(Try_Finish_Round)
		
	
func Try_Finish_Round():
	
	if Active_Game:
		Active_Game.GameOver.disconnect(Try_Finish_Round)
		Active_Game.rpc_finish.rpc()
		
	Round += 1		
	Ended_Round.emit()	
	State = SessionState.Reconfiguring
	Level.demolish()
	
	if not Level.demolished.is_connected(Try_Vote):
		Level.demolished.connect(Try_Vote)
		
	
func Try_Reset_Session():
	
	Level.demolish()
	State = SessionState.Lobby
	Round = 0
	
	for game : Game in All_Games:
		game.rpc_reset.rpc()
	

func add_player(peer_id):
	
	if not is_multiplayer_authority():
		return
	
	print(str(peer_id) + " joined")
	var new_peer_humanoid = Humanoid_Prefab.instantiate()
	new_peer_humanoid.name = str(peer_id)
	new_peer_humanoid.ragdoll_change.connect(update_nameplate_for_ragdoll)
	Humanoids.append(new_peer_humanoid)
	add_child(new_peer_humanoid)
	rpc_respawn_player.rpc(new_peer_humanoid.get_path())
	var screenname = get_humanoids_screenname(new_peer_humanoid)
	HUD.add_nameplate(new_peer_humanoid.name, screenname, new_peer_humanoid.find_child('*head').get_path())
	Created_Humanoid.emit(new_peer_humanoid)	
	
	rpc_CommissionSession.rpc_id(peer_id, session_rng.seed)
	Level.init_for_new_client(peer_id)
	
	for game : Game in All_Games:	
			
		if game.State == game.GameState.reset:
			game.rpc_reset.rpc_id(peer_id)
			
		elif game.State == game.GameState.playing:
			game.rpc_play.rpc_id(peer_id)
			
		elif game.State == game.GameState.finished:
			game.rpc_finish.rpc_id(peer_id)
			
		game.handle_player_joining(peer_id)
	
	wig_manager.handle_player_joining(peer_id)
	
	return new_peer_humanoid


func handle_new_humanoid(new_humanoid):
	
	new_humanoid.ragdoll_change.connect(update_nameplate_for_ragdoll)
	var screenname = get_humanoids_screenname(new_humanoid)
	HUD.add_nameplate(new_humanoid.name, screenname, new_humanoid.find_child('*head').get_path())
	

func remove_player(peer_id):
	
	print(str(peer_id) + " left")
	Client_Screennames.erase(peer_id)
	var players_humanoid = get_node_or_null(str(peer_id))
	
	if players_humanoid:
		Destroying_Humanoid.emit(players_humanoid.get_path())
		
		for game : Game in All_Games:
			game.handle_player_leaving(peer_id)
			
		wig_manager.handle_player_leaving(peer_id)
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
	
	session_rng.seed = Seed
	print(multiplayer.get_unique_id(), " session seed: ", session_rng.seed)			
	Level.seed_procedural_generators(hash(session_rng.randi()))
	Commissioned = true
			
	  
	
func update_nameplate_for_ragdoll(ragdoll_state, node):
	
	if not node.is_in_group("humanoids"):
		pass
		
	elif ragdoll_state:
		HUD.modify_nameplate(node.name, {
			"theme_override_colors/font_color" : Color.GRAY, 
			"theme_override_font_sizes/font_size" : 16
			})
	else:
		HUD.modify_nameplate(node.name, {
			"theme_override_colors/font_color" : Color.WHITE,
			"theme_override_font_sizes/font_size" : 20
			})


func fix_out_of_bounds():
	
	for humanoid in Humanoids:
		
		if not node_is_in_bounds(humanoid):		
			rpc_respawn_player.rpc(humanoid.get_path())
			

func node_is_in_bounds(node):
	
	var bounds = Level.room.Current_Size
	
	if not Level:
		return true
	elif abs(node.global_position.x) > bounds / 1.99:
		return false
	elif node.global_position.y > bounds or node.global_position.y < -1:
		return false
	elif abs(node.global_position.z) > bounds / 1.99:
		return false	
	else:
		return true
	
	#raycast.global_position = node.global_position + Vector3.DOWN #move raycast to node position
	#raycast.target_position = Vector3.UP * Level.Map_Size * 5 #shoot it up to the ceiling
	#raycast.force_raycast_update()	
	#var hit_the_ceiling = raycast.is_colliding()	
	#
	#raycast.global_position = node.global_position + Vector3.UP
	#raycast.target_position = Vector3.DOWN * Level.Map_Size * 5 #shoot it to the floor
	#raycast.force_raycast_update()	
	#var hit_the_floor = raycast.is_colliding()
#
	#return hit_the_ceiling and hit_the_floor #node is considered inside level if it hits one


func local_screenname():
	
	if not multiplayer.has_multiplayer_peer():
		return
		
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
		
		
func get_eligible_game() -> Game:
	
	var eligable_games : Array[Game] = []
	
	for game : Game in All_Games:
		
		if game_vote_options.has(game):
			continue
		elif game.Players > Humanoids.size() and Humanoids.size() != 1:
			continue
		else:
			eligable_games.append(game)
			
	if eligable_games.size() > 0:
		return eligable_games.pick_random()
	elif game_vote_options.size() > 0:
		return game_vote_options[0]
	else:
		return null
