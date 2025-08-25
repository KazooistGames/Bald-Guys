extends Node

func create_host():
	
	var steam_peer : SteamMultiplayerPeer = SteamMultiplayerPeer.new()
	var error_code = steam_peer.create_host(0, [])
	
	if error_code:
		return error_code
	
	multiplayer.multiplayer_peer = steam_peer
	
	

func join_host(lobby_id):

	var steam_peer : SteamMultiplayerPeer = SteamMultiplayerPeer.new()
	var error_code = steam_peer.create_client(lobby_id, 0, [])
	
	if error_code:
		return error_code
	
	multiplayer.multiplayer_peer = steam_peer
