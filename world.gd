extends Node3D

const session_Prefab = preload("res://Scenes/session/session.tscn")

const PORT : int = 9999

const MAX_CONNECTIONS : int = 8

const ClientState = {
	Menus = 0,
	Session = 1,
}
@export var State = ClientState.Menus

@onready var viewPort = $SubViewportContainer/SubViewport

@onready var main_menu = $CanvasLayer/MainMenu
@onready var pause_menu = $CanvasLayer/PauseMenu

@onready var popup = $CanvasLayer/Popup
@onready var popup_message = $CanvasLayer/Popup/margin/vbox/Message
@onready var popup_acknowledge = $CanvasLayer/Popup/margin/vbox/Acknowledge

@onready var standard_network_menu = $CanvasLayer/MainMenu/margin/vbox/standard_vbox
@onready var address_entry = $CanvasLayer/MainMenu/margin/vbox/standard_vbox/AddressEntry
@onready var screenname_entry = $CanvasLayer/MainMenu/margin/vbox/standard_vbox/NameEntry

@onready var steam_network_menu = $CanvasLayer/MainMenu/margin/vbox/steam_vbox
@onready var use_steam : CheckButton = $CanvasLayer/MainMenu/margin/vbox/use_steam

@onready var mp_manager = $multiplayer

@onready var sessionSpawner = $SessionSpawner

@onready var music = $Music

var session : Session


func _ready():
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	music.play()
	use_steam.visible = SteamManager.is_valid
	use_steam.button_pressed = SteamManager.is_valid
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
		steam_network_menu.visible = use_steam.button_pressed
		standard_network_menu.visible = not steam_network_menu.visible
		
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

	var error
		
	if use_steam.button_pressed:
		error = SteamNetwork.create_host()
		
	elif screenname_entry.text == '':
		error = "Enter a screen name first!"
		
	else:
		error = EnetNetwork.create_host()
		
	if error:
		display_popup("Could not start server,\n ERROR: " + str(error), null)
		return error
	
	session = session_Prefab.instantiate()
	viewPort.add_child(session)
	multiplayer.peer_disconnected.connect(session.remove_player)
	session.Client_Screennames[1] = acquire_screenname()


func join_lobby():
	
	var error
	
	if use_steam.button_pressed:
		var lobby_id =  $CanvasLayer/MainMenu/margin/vbox/steam_vbox/lobby_entry.text
		SteamManager.join_lobby(int(lobby_id))
		
	elif screenname_entry.text  == '':
		error = "Enter a screen name first!"
		return
	
	else:
		var hostIP = "127.0.0.1" if address_entry.text == "" else address_entry.text
		error = EnetNetwork.join_host(hostIP)

	if error:
		display_popup("Could not join host,\n ERROR: " + str(error), null)
		return error

	var msg = "Server connection lost."
	multiplayer.server_disconnected.connect(func (): display_popup(msg, null))
	multiplayer.server_disconnected.connect(leave_session)
	main_menu.hide()


func leave_session():
		
	if session != null:
		session.queue_free()
		 	
	pause_menu.visible = false
	State = ClientState.Menus
	music.play()	
	
	if not multiplayer.has_multiplayer_peer():
		pass		
	elif multiplayer.is_server():
		multiplayer.peer_disconnected.disconnect(session.remove_player)
	else:
		multiplayer.server_disconnected.disconnect(leave_session)
		
	multiplayer.multiplayer_peer = null
	
	if use_steam.button_pressed:
		SteamManager.leave_lobby()

		
func quit():
	
	get_tree().quit()
	
	
func acquire_screenname():
	
	if use_steam.button_pressed:
		return Steam.getPersonaName()
	else:
		return screenname_entry.text
	
	
func introduce_myself_to_server():
	
	var player_name
	
	if use_steam.button_pressed:
		player_name = Steam.getPersonaName()
	else:
		player_name = screenname_entry.text
		
	rpc_set_client_screenname.rpc(player_name)
	
	
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
	
	if is_multiplayer_authority():
		session.add_player(id)



