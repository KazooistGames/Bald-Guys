extends Node

const APP_ID : int = 3782090 #this is Bald Guys
const PACKET_READ_LIMIT: int = 32

var lobby_data
var lobby_id: int = 0
var lobby_members: Array = []
var lobby_members_max: int = 10
var lobby_vote_kick: bool = false
var steam_id: int = 0
var steam_username: String = ""


var user_id : int = 0
var username : String = ''

var is_valid : bool = false


func _init() -> void:
	
	print("Initializing Steam Module")	
	var init_response : Dictionary = Steam.steamInitEx(APP_ID)

	if init_response['status'] > 0:
		print("failed to init steam!")
		get_tree().quit()
		
	else:	
		user_id = Steam.getSteamID()
		username = Steam.getPersonaName()
		is_valid = Steam.isSubscribed()
		print("Logged in as UserID %s" % user_id + ', ' + username)

	print(Steam.getBetaInfo())
	
	
func _ready() -> void:
	
	Steam.join_requested.connect(_on_lobby_join_requested)
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	#Steam.lobby_data_update.connect(_on_lobby_data_update)
	check_command_line()	
	
	
func _process(delta) -> void:
	
	Steam.run_callbacks()
	

func check_command_line() -> void:
	
	var these_arguments: Array = OS.get_cmdline_args()

	if these_arguments.size() <= 0:	# There are no arguments to process
		pass
	elif these_arguments[0] != "+connect_lobby":# A Steam connection argument exists
		pass
	elif int(these_arguments[1]) > 0:# Lobby invite exists so try to connect to it
		print("Command line lobby ID: %s" % these_arguments[1])
		join_lobby(int(these_arguments[1]))
		# At this point, you'll probably want to change scenes
		# Something like a loading into lobby screen
		
		
func list_lobbies() -> void:
	
	print("Requesting a lobby list")
	#Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.requestLobbyList()				


func _on_lobby_match_list(these_lobbies: Array) -> void:
	
	print(these_lobbies)
	
	for this_lobby in these_lobbies:
		var lobby_name: String = Steam.getLobbyData(this_lobby, "name")
		var lobby_mode: String = Steam.getLobbyData(this_lobby, "mode")
		var lobby_num_members: int = Steam.getNumLobbyMembers(this_lobby)
		var lobby_button: Button = Button.new()
		lobby_button.set_text("Lobby %s: %s [%s] - %s Player(s)" % [this_lobby, lobby_name, lobby_mode, lobby_num_members])
		lobby_button.set_size(Vector2(800, 50))
		lobby_button.set_name("lobby_%s" % this_lobby)
		lobby_button.connect("pressed", Callable(self, "join_lobby").bind(this_lobby))
		## Add the new lobby to the list
		#$CanvasLayer/MainMenu/margin/vbox/steam_vbox/scroll/list.add_child(lobby_button)
				
				
func create_lobby() -> void:

	if lobby_id == 0:	# Make sure a lobby is not already set
		Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, lobby_members_max)
		

func _on_lobby_created(connect: int, this_lobby_id: int) -> void:
	
	if connect == 1:
		lobby_id = this_lobby_id
		print("Created a lobby: %s" % lobby_id)
		Steam.setLobbyJoinable(lobby_id, true)
		Steam.setLobbyData(lobby_id, "name", "KazooistGames test lobby")
		Steam.setLobbyData(lobby_id, "mode", "GodotSteam test")
		# Allow P2P connections to fallback to being relayed through Steam if needed
		var set_relay: bool = Steam.allowP2PPacketRelay(true)
		print("Allowing Steam to be relay backup: %s" % set_relay)
	
		
func join_lobby(remote_lobby_id: int) -> void:
	
	print("Attempting to join lobby %s" % remote_lobby_id)
	lobby_members.clear()	# Clear any previous lobby members lists
	Steam.joinLobby(remote_lobby_id)	# Make the lobby join request to Steam
	print(Steam.getLobbyData(remote_lobby_id, 'name'))
	print(Steam.getLobbyOwner(remote_lobby_id))
	
	
func _on_lobby_joined(remote_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:

	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		lobby_id = remote_lobby_id
		get_lobby_members()

	else:
		print("Failed to join this chat room: %s" % response)
	
	
func _on_lobby_join_requested(this_lobby_id: int, friend_id: int) -> void:
	
	var owner_name: String = Steam.getFriendPersonaName(friend_id)
	print("Joining %s's lobby..." % owner_name)
	join_lobby(this_lobby_id)
	
	
func leave_lobby() -> void:

	if lobby_id == 0:
		return
		
	Steam.leaveLobby(lobby_id)	# Send leave request to Steam
	lobby_id = 0
	
	for this_member in lobby_members:	# Close session with all users
		
		if this_member['steam_id'] != steam_id:	# Make sure this isn't your Steam ID
			# Close the P2P session using the Networking class
			Steam.closeP2PSessionWithUser(this_member['steam_id'])
			
	lobby_members.clear()


func get_lobby_members() -> void:

	lobby_members.clear()
	var num_of_members: int = Steam.getNumLobbyMembers(lobby_id)

	for this_member in range(0, num_of_members):	# Get the data of these players from Steam
		var member_steam_id: int = Steam.getLobbyMemberByIndex(lobby_id, this_member)
		var member_steam_name: String = Steam.getFriendPersonaName(member_steam_id)
		lobby_members.append({"steam_id":member_steam_id, "steam_name":member_steam_name})

