extends Node3D

const Player_Prefab = preload("res://Scenes/player/player.tscn")

const Humanoid_Prefab = preload("res://Scenes/humanoid/humanoid.tscn")

const wigArena_Prefab = preload("res://Scenes/games/wigArena.tscn")


const PORT = 9999

var enet_peer = ENetMultiplayerPeer.new()


var map


@onready var main_menu = $CanvasLayer/MainMenu

@onready var lobby_menu = $CanvasLayer/LobbyMenu

@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry

@onready var viewPort = $SubViewportContainer/SubViewport

@onready var spawner = $MultiplayerSpawner

@onready var hud = $HUD


@export var LOCAL_PLAYER : Node3D

@export var Players = {}


const SessionState = {
	Menu = 0,
	Lobby = 1,
	Session = 2,
}


@export var Session_State = SessionState.Menu
func _ready():
	LOCAL_PLAYER = spawn_local_player_controller()


func _process(_delta):
	
	if Session_State == SessionState.Session:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	main_menu.visible = Session_State == SessionState.Menu
	lobby_menu.visible = Session_State == SessionState.Lobby

	if not is_multiplayer_authority():
		return

	elif not map:
		map = viewPort.get_node_or_null("map")

	elif not map.Commissioned:
		
		for player in Players.keys():
			var new_humanoid = add_player_humanoid(player)
			map.set_spawn_position(new_humanoid)
		map.Commissioned = true

	elif Session_State != SessionState.Session:
		Session_State = SessionState.Session
		var humanoids = get_tree().get_nodes_in_group("humanoids")
		
		for humanoid in humanoids:
			_handoff.rpc(humanoid.name, str(humanoid.name).to_int())


	if not multiplayer.is_server() or not map: #only do server/host items from here on out
		return
		
	elif map.State == map.GameState.Setup:  
		pass
		
	elif map.State == map.GameState.Countdown:
		hud.set_public_service_announcement.rpc(str(map.CountdownTimer))
		
	elif map.State == map.GameState.Playing:
		pass
		
	elif map.State == map.GameState.Finished:
		pass


func _unhandled_input(_event):
	
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()


func start_host_lobby():
	
	main_menu.hide()
	enet_peer.create_server(PORT)
	Players[1] = "host"
	
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(tally_player)
	multiplayer.peer_disconnected.connect(untally_player)

	Session_State = SessionState.Lobby
	#upnp_setup() #removed and using port forwarding instead


func join_lobby():
	
	main_menu.hide()
	var hostIP = "localhost" if address_entry.text == "" else address_entry.text
	enet_peer.create_client(hostIP, PORT)
	multiplayer.multiplayer_peer = enet_peer
	#LOCAL_PLAYER = spawn_local_player_controller()
	Session_State = SessionState.Lobby

func start_game():
	
	if multiplayer.is_server():
		map = wigArena_Prefab.instantiate()
		viewPort.add_child(map)
	

func spawn_local_player_controller():
	
	var player = Player_Prefab.instantiate()
	viewPort.add_child(player)
	return player


func add_player_humanoid(peer_id):
	
	print(str(peer_id) + " joined")
	var playerHumanoid = Humanoid_Prefab.instantiate()
	playerHumanoid.name = str(peer_id)
	viewPort.add_child(playerHumanoid)
	return playerHumanoid


func tally_player(peer_id):
	
	Players[peer_id] = "client"


func untally_player(peer_id):
	
	print(str(peer_id) + " left")
	Players.erase(peer_id)
	var playerHumanoid = viewPort.get_node_or_null(str(peer_id))
	
	if playerHumanoid:
		playerHumanoid.queue_free()


@rpc("call_local")
func _handoff(node_name, auth_id):
	
	viewPort.get_node(str(node_name)).set_multiplayer_authority(auth_id)

func upnp_setup():
	
	var upnp = UPNP.new()
	var discover_result = upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, \
	"UPNP Discover Failed! Error %s" % discover_result)
	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), \
	"UPNP Invalid Gateway!")
	var map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, \
	"UPNP Port Mapping Failed! Error %s" % map_result)
	print("Success! Join Address: %s" % upnp.query_external_address())
	







