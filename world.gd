extends Node3D

const Player_Prefab = preload("res://Scenes/player/player.tscn")

const Humanoid_Prefab = preload("res://Scenes/humanoid/humanoid.tscn")

const wigArena_Prefab = preload("res://Scenes/games/wigArena.tscn")


const PORT = 9999

var enet_peer = ENetMultiplayerPeer.new()


var map


@onready var main_menu = $CanvasLayer/MainMenu

@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry

@onready var viewPort = $SubViewportContainer/SubViewport

@onready var spawner = $MultiplayerSpawner

@onready var hud = $HUD


@export var LOCAL_PLAYER : Node3D


const SessionState = {
	Menu = 0,
	Lobby = 1,
	Playing = 2,
}

@export var Session_State = SessionState.Menu


func _process(_delta):
	
	if not map:
		map = viewPort.get_node_or_null("map")
		
	elif not map.Commissioned:
		map.Commissioned = true
		
	elif not LOCAL_PLAYER:
		spawner.spawned.connect(map.set_spawn_position)
		LOCAL_PLAYER = spawn_local_player_controller()
		if is_multiplayer_authority():
			map.set_spawn_position(add_player_humanoid(multiplayer.get_unique_id()))
	
	elif not is_multiplayer_authority(): #only do server/host items from here on out
		return
		
	elif map.State == map.GameState.Setup:
		pass
		
	elif map.State == map.GameState.Countdown:
		hud.set_public_service_announcement.rpc(str(map.CountdownTimer))
		
	elif map.State == map.GameState.Playing:
		pass


func _unhandled_input(_event):
	
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()


func _on_host_button_pressed():
	
	main_menu.hide()
	enet_peer.create_server(PORT)
	
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player_humanoid)
	multiplayer.peer_disconnected.connect(remove_player_humanoid)

	map = wigArena_Prefab.instantiate()
	viewPort.add_child(map)
	#upnp_setup() #removed and using port forwarding instead


func _on_join_button_pressed():
	
	main_menu.hide()
	var hostIP = "localhost" if address_entry.text == "" else address_entry.text
	enet_peer.create_client(hostIP, PORT)
	multiplayer.multiplayer_peer = enet_peer
	#LOCAL_PLAYER = spawn_local_player_controller()


func spawn_local_player_controller():
	
	var player = Player_Prefab.instantiate()
	viewPort.add_child(player)
	return player


func add_player_humanoid(peer_id):
	
	print(peer_id)
	var playerHumanoid = Humanoid_Prefab.instantiate()
	playerHumanoid.name = str(peer_id)
	viewPort.add_child(playerHumanoid)
	return playerHumanoid


func remove_player_humanoid(peer_id):
	
	print(peer_id)
	var playerHumanoid = viewPort.get_node_or_null(str(peer_id))
	
	if playerHumanoid:
		playerHumanoid.queue_free()


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
	




