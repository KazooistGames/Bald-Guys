extends Node

const PORT : int = 9999

const MAX_CONNECTIONS : int = 8

var using_steam : bool = false

@onready var world = $".."



func host(lobby_name):
	
	if lobby_name == '':
		world.display_popup("Enter a screen name first!", null)
		return
	
	if using_steam:
		var steam_peer = Steam 
		var error_code = steam_peer.create_server(PORT, MAX_CONNECTIONS)
		
		if error_code:
			return error_code
		
		multiplayer.multiplayer_peer = steam_peer
		
	else:	
		var enet_peer = ENetMultiplayerPeer.new()
		var error_code = enet_peer.create_server(PORT, MAX_CONNECTIONS)
		
		if error_code:
			return error_code
		
		multiplayer.multiplayer_peer = enet_peer
	


func join(host):
	
	var enet_peer = ENetMultiplayerPeer.new()
	var error_code = enet_peer.create_client(world, PORT)
	
	if error_code:
		return error_code
	
	multiplayer.multiplayer_peer = enet_peer
	

	
