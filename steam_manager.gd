extends Node

var app_id : int = 3782090
var user_id : int = 0
var username : String = ''

var is_valid : bool = false


func _init() -> void:
	
	print("Initializing Steam Module")	
	var init_response : Dictionary = Steam.steamInitEx(app_id)
	
	if init_response['status'] > 0:
		print("failed to init steam!")
		get_tree().quit()
		
	else:	
		user_id = Steam.getSteamID()
		username = Steam.getPersonaName()
		is_valid = Steam.isSubscribed()
		print("Logged in as UserID %s" % user_id + ', ' + username)

	
	
func _process(delta) -> void:
	
	Steam.run_callbacks()
	
	
