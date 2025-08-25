extends Node

const PORT : int = 9999
const MAX_CONNECTIONS : int = 8


func create_host():

	var enet_peer : ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error_code = enet_peer.create_server(PORT, MAX_CONNECTIONS)
	
	if error_code:
		return error_code
	
	multiplayer.multiplayer_peer = enet_peer
	


func join_host(lobby_id):
	
	var enet_peer : ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error_code = enet_peer.create_client(lobby_id, PORT)
	
	if error_code:
		return error_code
	
	multiplayer.multiplayer_peer = enet_peer
		

	
