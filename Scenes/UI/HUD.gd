extends CanvasLayer

@onready var PSA = $MarginContainer/Label

@rpc("call_local", "authority")
func set_public_service_announcement(message = ""):
	PSA.text = message
