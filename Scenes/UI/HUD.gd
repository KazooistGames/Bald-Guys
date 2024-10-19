extends CanvasLayer

@onready var scoreboard = $Scoreboard

@onready var names_text = $Scoreboard/Names/Rows/Values

@onready var times_text = $Scoreboard/Times/Rows/Values

@onready var progress_fill = $Progress/Fill

@onready var progress_backdrop = $Progress/BackDrop

@onready var PSA = $PSA/Label
var psaTimeToLive = 0


@export var TableValues = {}

@export var ProgressPercent = 0

const bar_length = 1000
const bar_width = 75
	
	
func _ready():
	progress_backdrop.custom_minimum_size = Vector2(bar_length, bar_width)
	
func _process(delta):
	
	scoreboard.visible = Input.is_action_pressed("tab")
	progress_fill.custom_minimum_size.x = bar_length * clampf(ProgressPercent, 0.0, 1.0)

	names_text.text = ""
	times_text.text = ""
	
	for key in TableValues:
		names_text.text += "\n" + str(key)
	
	for value in TableValues.values():
		times_text.text += "\n" + "%3.2f" % value
	
	
	if(psaTimeToLive > 0):
		psaTimeToLive -= delta
		
	else:
		PSA.text = ""
		
	
func get_public_service_announcement():
	
	return PSA.text
	
		
@rpc("call_local", "authority")
func set_public_service_announcement(message = ""):
	
	if(PSA.text != ""):
		PSA.text = message
		psaTimeToLive = 1
	
