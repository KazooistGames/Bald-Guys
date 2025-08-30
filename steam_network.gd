extends Node


func create_host():
	
	var steam_peer : SteamMultiplayerPeer = SteamMultiplayerPeer.new()
	var error_code = steam_peer.create_host(0, [])
	
	if error_code:
		return error_code
	
	multiplayer.multiplayer_peer = steam_peer
	SteamManager.create_lobby()
	

func join_host(host_id):
	
	var steam_peer : SteamMultiplayerPeer = SteamMultiplayerPeer.new()
	var error_code = steam_peer.create_client(host_id, 0, [])
	
	if error_code:
		return error_code
	
	multiplayer.multiplayer_peer = steam_peer
	
