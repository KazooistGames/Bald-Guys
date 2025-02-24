extends CanvasLayer

@export var TableValues = {}

@onready var nameplates = $Nameplates

@onready var PSA = $MarginContainer/PSA
@onready var ping = $MarginContainer/ping

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

	
func update_nameplate(key, coordinates, label):
	
	var nameplate = nameplates.find_child(str(key), false, false)
	var camera = get_viewport().get_camera_3d()
	
	if nameplate == null or camera == null:
		pass
	else:
		var screen_coordinates = camera.unproject_position(coordinates)
		var screen_size = DisplayServer.screen_get_size()
		var screen_offset = Vector2(0, screen_size.y / 50.0)	
		var label_size = nameplate.size / 2.0
		nameplate.position = screen_coordinates - screen_offset - label_size 
		nameplate.visible = not camera.is_position_behind(coordinates)
		nameplate.text = label
	

func add_nameplate(key, label):
	
	var new_nameplate = Label.new()
	new_nameplate.name = key
	new_nameplate.text = label
	new_nameplate.add_theme_color_override("font_shadow_color", Color.BLACK)
	new_nameplate.add_theme_font_size_override("font_size", 20)
	new_nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_nameplate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nameplates.add_child(new_nameplate)
	return new_nameplate
	
	
func remove_nameplate(key):
	
	var nameplate = nameplates.find_child(str(key), false, false)
	
	if nameplate != null:
		nameplate.queue_free()
	
	
func modify_nameplate(key, variable, value):
	
	var nameplate = nameplates.find_child(str(key), false, false)
	
	if nameplate != null:
		nameplate.set(variable, value)
	
	
func set_ping_indicator(value):
	
	value = (roundf(value * 10.0)) / 10.0

	var ping_color_grade = Color.WHITE_SMOKE
	
	if value <= 50:
		ping_color_grade = Color.LIME_GREEN
	elif value <= 150:
		ping_color_grade = Color.YELLOW
	elif value <= 500:
		ping_color_grade = Color.RED
	else:
		ping_color_grade = Color.DARK_RED
		
	ping.add_theme_color_override("font_color", ping_color_grade)
	ping.text = str(value) + " ms"
