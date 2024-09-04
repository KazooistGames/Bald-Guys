extends Node


@onready var start_button = $margin/vbox/StartButton



func _process(delta):
	start_button.visible = multiplayer.is_server()


func _on_start_button_pressed():
	pass # Replace with function body.
