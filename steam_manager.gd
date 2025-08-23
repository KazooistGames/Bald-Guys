extends Node

var steam_app_id : int = 3782090
var steam_id : int = 0
var steam_username : String = ''

var is_valid : bool = false

func _init() -> void:
	
	print("Initializing Steam Module")
	OS.set_environment("SteamAppId", str(steam_app_id))
	OS.set_environment("SteamGameId", str(steam_app_id))
	
	
func _process(delta) -> void:
	
	Steam.run_callbacks()
	
	
func initialize_steam() -> void:
	
	var init_response : Dictionary = Steam.steamInitEx()
	
	if init_response['status'] > 0:
		print("failed to init steam!")
		get_tree().quit()
		
	else:	
		steam_id = Steam.getSteamID()
		steam_username = Steam.getPersonaName()
		is_valid = Steam.isSubscribed()
		print("Logged in as UserID %s" % steam_id + ', ' + steam_username)
