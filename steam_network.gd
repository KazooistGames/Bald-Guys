extends Node



func create_host():
	
	var steam_peer : SteamMultiplayerPeer = SteamMultiplayerPeer.new()
	var error_code = steam_peer.create_host(0, [])
	
	if error_code:
		return error_code
	
	multiplayer.multiplayer_peer = steam_peer
	SteamManager.create_lobby()
	SteamManager.list_lobbies()
	

func join_host(lobby_id):

	var steam_peer : SteamMultiplayerPeer = SteamMultiplayerPeer.new()
	var error_code = steam_peer.create_client(lobby_id, 0, [])
	
	if error_code:
		return error_code
	
	multiplayer.multiplayer_peer = steam_peer
	
	
	
func check_command_line() -> void:
	var these_arguments: Array = OS.get_cmdline_args()

	# There are arguments to process
	if these_arguments.size() > 0:

		# A Steam connection argument exists
		if these_arguments[0] == "+connect_lobby":

			# Lobby invite exists so try to connect to it
			if int(these_arguments[1]) > 0:

				# At this point, you'll probably want to change scenes
				# Something like a loading into lobby screen
				print("Command line lobby ID: %s" % these_arguments[1])
				join_host(int(these_arguments[1]))
