extends Node3D

const session_Prefab = preload("res://Scenes/session/session.tscn")

const PORT = 9999

const MAX_CONNECTIONS = 8

const ClientState = {
	Menus = 0,
	Session = 1,
}
@export var State = ClientState.Menus

@onready var viewPort = $SubViewportContainer/SubViewport

@onready var main_menu = $CanvasLayer/MainMenu
@onready var pause_menu = $CanvasLayer/PauseMenu

@onready var popup = $CanvasLayer/Popup
@onready var popup_message = $CanvasLayer/Popup/MarginContainer/VBoxContainer/Message
@onready var popup_acknowledge = $CanvasLayer/Popup/MarginContainer/VBoxContainer/Acknowledge

@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
@onready var screenname_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/NameEntry

@onready var sessionSpawner = $SessionSpawner

@onready var music = $Music

var session


func _ready():
	
	music.play()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	multiplayer.connected_to_server.connect(introduce_myself_to_server)
	multiplayer.connected_to_server.connect(acknowledge_popup)
	
	
func _unhandled_input(_event):
	
	if State != ClientState.Session:
		pass
		
	elif Input.is_action_just_pressed("pause"):
		pause_menu.visible = not pause_menu.visible


func _process(delta):
	
	if State == ClientState.Menus:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		music.volume_db = move_toward(music.volume_db, -24, delta * 6)
		
	elif pause_menu.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		music.volume_db = move_toward(music.volume_db, -72, delta * 6)
		
	elif State == ClientState.Session:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)		
		music.volume_db = move_toward(music.volume_db, -72, delta * 6)
				
	if music.volume_db <= -72:
		music.stop()
		
	main_menu.visible = State == ClientState.Menus

	if not multiplayer.has_multiplayer_peer():
		return
		
	elif multiplayer.multiplayer_peer.get_connection_status() == 0:
		display_popup("Failed to connect", null)
		multiplayer.multiplayer_peer = null
	
	elif multiplayer.multiplayer_peer.get_connection_status() == 1:
		var seconds = Time.get_time_dict_from_system()["second"]
		var ellipses = ""
		for i in range(seconds % 4):
			ellipses += "."
		display_popup("connecting" + ellipses, null)
		
	elif not is_multiplayer_authority():
		pass

	elif not session:
		session = viewPort.get_node_or_null("session")
		State = ClientState.Menus

	elif State != ClientState.Session:
		State = ClientState.Session


func _notification(what):
	
	if State != ClientState.Session:
		pass
	
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		pause_menu.visible = true


func start_host_lobby():
	
	if get_screenname_entry() == '':
		display_popup("Enter a screen name first!", null)
		return
	
	var enet_peer = ENetMultiplayerPeer.new()
	main_menu.hide()
	var error_code = enet_peer.create_server(PORT, MAX_CONNECTIONS)
	
	if error_code:
		display_popup("Could not start server,\n ERROR CODE: " + str(error_code), null)
		return error_code
	
	multiplayer.multiplayer_peer = enet_peer
	
	session = session_Prefab.instantiate()
	viewPort.add_child(session)
	
	multiplayer.peer_connected.connect(session.add_player)
	multiplayer.peer_disconnected.connect(session.remove_player)
	session.Client_Screennames[1] = get_screenname_entry()


func join_lobby():
	
	if get_screenname_entry() == '':
		display_popup("Choose a screen name first!", null)
		return
		
	elif address_entry.text == "":
		display_popup("Enter Host Address!", null)
		return
	
	var enet_peer = ENetMultiplayerPeer.new()
	main_menu.hide()
	
	var hostIP = "127.0.0.1" if address_entry.text == "" else address_entry.text
	var error_code = enet_peer.create_client(hostIP, PORT)
	
	if error_code:
		display_popup("Could not join host,\n ERROR CODE: " + str(error_code), null)
		return error_code
	
	multiplayer.multiplayer_peer = enet_peer

	multiplayer.server_disconnected.connect(func (): display_popup("Server connection lost.", null))
	multiplayer.server_disconnected.connect(leave_session)
	

func leave_session():
		
	if session != null:
		session.queue_free()
		 	
	pause_menu.visible = false
	State = ClientState.Menus
	music.play()	
	
	if not multiplayer.has_multiplayer_peer():
		pass	
		
	elif multiplayer.is_server():
		multiplayer.peer_connected.disconnect(session.add_player)
		multiplayer.peer_disconnected.disconnect(session.remove_player)
		
	else:
		multiplayer.server_disconnected.disconnect(leave_session)
		
	multiplayer.multiplayer_peer = null

	
		
func quit():
	
	get_tree().quit()
	
	
func introduce_myself_to_server():
	
	var player_name = get_screenname_entry()
	rpc_set_client_screenname.rpc(player_name)
	
	
func get_screenname_entry():
	
	return screenname_entry.text
	
	
func display_popup(message, callback):
	
	popup_message.text = message
	popup.visible = true
	
	if callback == null:
		pass
	elif not callback is Callable:
		pass
	else:
		popup_acknowledge.pressed.connect(callback)
	
	
func acknowledge_popup():
	
	popup.visible = false
	
	for connection in popup_acknowledge.pressed.get_connections():
		
		var callback = connection["callable"]
		
		if callback != acknowledge_popup:
			popup_acknowledge.pressed.disconnect(callback)
		
	
@rpc("call_local", "reliable")
func rpc_handoff_object(path, auth_id):
	
	path = str(path).replace(str(get_path()), "")
	var node = get_node(path)
	
	if node:
		node.set_multiplayer_authority(auth_id)
		
		
@rpc("call_remote", "reliable", "any_peer")	
func rpc_set_client_screenname(player_name):
	
	if session == null:
		return
		
	var id = multiplayer.get_remote_sender_id()
	session.Client_Screennames[id] = player_name


