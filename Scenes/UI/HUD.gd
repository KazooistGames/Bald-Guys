extends CanvasLayer

@onready var PSA = $MarginContainer/Label
var psaTimeToLive = 0

@rpc("call_local", "authority")
func set_public_service_announcement(message = ""):
	if(PSA.text != ""):
		PSA.text = message
		psaTimeToLive = 1
	
func get_public_service_announcement():
	return PSA.text
	
	
func _process(delta):
	if(psaTimeToLive > 0):
		psaTimeToLive -= delta
		
	else:
		PSA.text = ""
