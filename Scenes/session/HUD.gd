extends CanvasLayer

@export var TableValues = {}

@onready var nameplates = $Nameplates

@onready var PSA = $PSA/Label

var psaTTL = 1

	
func _process(delta):

	if psaTTL > 0:
		psaTTL -= min(delta, psaTTL)
		
	elif psaTTL < 0:
		pass
		
	else:
		PSA.text = ""
		
		
@rpc("call_local", "reliable")
func set_psa(message = "", ttl = 1):
	
	PSA.text = message
	psaTTL = ttl
	

func get_psa():

	return PSA.text
	
	
func update_nameplate(player_id, coordinates, label):
	
	var nameplate = nameplates.find_child(str(player_id), false, false)
	
	if nameplate != null:
		var camera = get_viewport().get_camera_3d()
		var screen_coordinates = camera.unproject_position(coordinates)
		var screen_size = DisplayServer.screen_get_size()
		var screen_offset = Vector2(0, screen_size.y / 50.0)	
		var label_size = nameplate.size / 2.0
		nameplate.position = screen_coordinates - screen_offset - label_size 
		nameplate.visible = not camera.is_position_behind(coordinates)
		nameplate.text = label
	

func add_nameplate(player_id, player_name):
	
	var new_nameplate = Label.new()
	new_nameplate.name = player_id
	new_nameplate.text = player_name
	new_nameplate.add_theme_color_override("font_shadow_color", Color.BLACK)
	new_nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_nameplate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nameplates.add_child(new_nameplate)
	
	
func remove_nameplate(player_id):
	
	var nameplate = nameplates.find_child(str(player_id), false, false)
	nameplate.queue_free()
	
	
