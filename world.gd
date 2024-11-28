extends Node3D

const Player_Interface_Prefab = preload("res://Scenes/player/player_interface.tscn")

const session_Prefab = preload("res://Scenes/session/session.tscn")

const PORT = 9999

const MAX_CONNECTIONS = 8

var session

@onready var main_menu = $CanvasLayer/MainMenu

@onready var pause_menu = $CanvasLayer/PauseMenu

@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry

@onready var viewPort = $SubViewportContainer/SubViewport

@onready var sessionSpawner = $MultiplayerSpawner

@export var LOCAL_PLAYER_INTERFACE : Node3D

@export var Player_Lobby_Dict = {}


const ClientState = {
	Lobby = 0,
	Session = 1,
}

@export var State = ClientState.Lobby


func _ready():
	
	LOCAL_PLAYER_INTERFACE = Player_Interface_Prefab.instantiate()
	viewPort.add_child(LOCAL_PLAYER_INTERFACE)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	sessionSpawner.spawned.connect(handle_new_session_spawn)
	
	
func _unhandled_input(_event):
	
	if State != ClientState.Session:
		pass
		
	elif Input.is_action_just_pressed("pause"):
		pause_menu.visible = not pause_menu.visible


func _process(_delta):
	
	if State != ClientState.Session or pause_menu.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	elif State == ClientState.Session:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	main_menu.visible = State == ClientState.Lobby

	if not multiplayer.has_multiplayer_peer():
		return
		
	elif not is_multiplayer_authority():
		return

	elif not session:
		session = viewPort.get_node_or_null("session")
		State = ClientState.Lobby

	elif State != ClientState.Session:
		State = ClientState.Session
		
	else:
		pass


func _notification(what):
	
	if State != ClientState.Session:
		pass
	
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		pause_menu.visible = true
		
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		pause_menu.visible = false


func start_host_lobby():
	
	var enet_peer = ENetMultiplayerPeer.new()
	main_menu.hide()
	var error = enet_peer.create_server(PORT, MAX_CONNECTIONS)
	
	if error:
		return error
	
	Player_Lobby_Dict[1] = "host"
	
	multiplayer.multiplayer_peer = enet_peer
	
	session = session_Prefab.instantiate()
	session.Created_Player_Humanoid.connect(give_humanoid_to_client)
	viewPort.add_child(session)
	
	multiplayer.peer_connected.connect(add_player_to_session)
	multiplayer.peer_disconnected.connect(remove_player_from_session)


func join_lobby():
	
	var enet_peer = ENetMultiplayerPeer.new()
	main_menu.hide()
	
	var hostIP = "127.0.0.1" if address_entry.text == "" else address_entry.text
	enet_peer.create_client(hostIP, PORT)
		
	multiplayer.multiplayer_peer = enet_peer
		
	multiplayer.server_disconnected.connect(leave_session)


func add_player_to_session(peer_id):
	
	print(str(peer_id) + " joined")
	Player_Lobby_Dict[peer_id] = "client"
	
	session.create_player_humanoid(peer_id)
	
	
func remove_player_from_session(peer_id):
	
	print(str(peer_id) + " left")
	Player_Lobby_Dict.erase(peer_id)
	
	session.destroy_player_humanoid(peer_id)

		
		
func give_humanoid_to_client(humanoid):
	
	var peer_id = str(humanoid.name).to_int()
	humanoid.set_multiplayer_authority(peer_id)
	
	if multiplayer.get_unique_id() == peer_id:
		LOCAL_PLAYER_INTERFACE.character = humanoid


func handle_new_session_spawn(new_session):
	
	new_session.Created_Player_Humanoid.connect(give_humanoid_to_client)



func leave_session():
		
	if not multiplayer.has_multiplayer_peer():
		pass
		
	elif multiplayer.is_server():
		multiplayer.peer_connected.disconnect(add_player_to_session)
		multiplayer.peer_disconnected.disconnect(remove_player_from_session)
	
	else:
		multiplayer.server_disconnected.disconnect(leave_session)
		
	multiplayer.multiplayer_peer = null
	
	Player_Lobby_Dict.clear()
	pause_menu.visible = false
	
	if session != null:
		session.queue_free()
		
	State = ClientState.Lobby
		
		
func quit():
	
	get_tree().quit()
	
		
@rpc("call_local", "reliable")
func rpc_handoff_object(path, auth_id):
	
	path = str(path).replace(str(get_path()), "")
	var node = get_node(path)
	
	if node:
		node.set_multiplayer_authority(auth_id)
