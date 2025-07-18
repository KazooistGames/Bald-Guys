class_name Hud extends CanvasLayer

const progress_bar_length = 1000
const progress_bar_width = 75

var Scores : Dictionary = {}
var Goal : float = 0.0
var ProgressPercent = 0

@onready var scoreboard = $Scoreboard
@onready var names_text = $Scoreboard/Names/Rows/Values
@onready var scores_text = $Scoreboard/Scores/Rows/Values
@onready var progress_fill = $Progress/Fill
@onready var progress_backdrop = $Progress/BackDrop

@onready var nameplates = $Nameplates
@onready var PSA = $MarginContainer/PSA
@onready var ping = $MarginContainer/ping

@onready var session = get_parent()

var psaTTL = 1
	

func _ready():
	
	progress_backdrop.custom_minimum_size = Vector2(progress_bar_length, progress_bar_width)
	
	
func _process(delta):
	
	update_scoreboard(delta)

	if psaTTL > 0:
		psaTTL -= min(delta, psaTTL)
		
	elif psaTTL < 0:
		pass
		
	else:
		PSA.text = ""
		
		
func update_scoreboard(_delta) -> void:
	
	scoreboard.visible = Input.is_action_pressed("tab")
	progress_fill.custom_minimum_size.x = progress_bar_length * clampf(ProgressPercent, 0.0, 1.0)

	names_text.text = ""
	scores_text.text = ""
	
	for key in Scores:
		names_text.text += "\n" + str(key)
	
	for value in Scores.values():
		scores_text.text += "\n" + "%3.2f" % value
		
	var local_name = session.local_screenname()
	#print(local_name)
	if Scores.has(local_name):
		var local_score = Scores[local_name]
		ProgressPercent = clampf(local_score/Goal, 0.0, 1.0)
		#print(multiplayer.get_unique_id(), local_score)
		
		
@rpc("call_local", "reliable")
func set_psa(message = "", ttl = 1):
	
	message = str(message)
	PSA.text = message
	psaTTL = ttl
	

func get_psa():

	return PSA.text

	
func update_nameplate(key, coordinates, label, invisible = false):
	
	var nameplate = nameplates.find_child(str(key), false, false)
	var camera = get_viewport().get_camera_3d()
	
	if nameplate == null or camera == null:
		pass
	else:
		var screen_coordinates = camera.unproject_position(coordinates)
		var screen_size = DisplayServer.screen_get_size()
		var screen_offset = Vector2(0, screen_size.y / 50.0)	
		var label_size = nameplate.size / 2.0
		var position_target = screen_coordinates - screen_offset - label_size
		var position_delta = position_target - nameplate.position
		var step = pow(position_delta.length(), 2.0) / 75
		nameplate.position = nameplate.position.move_toward(position_target, step)
		nameplate.visible = not camera.is_position_behind(coordinates) and not invisible
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
	
	#
#func set_player_score(player_id : int) -> void:
	#pass
	#
	#
#func get_player_score(player_id : int) -> float:
	#return 0.0


func set_progress_label(label : String) -> void:
	
	$Progress/Label.text = label
