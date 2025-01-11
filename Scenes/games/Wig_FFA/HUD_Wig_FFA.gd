extends CanvasLayer

@onready var scoreboard = $Scoreboard

@onready var names_text = $Scoreboard/Names/Rows/Values

@onready var times_text = $Scoreboard/Times/Rows/Values

@onready var progress_fill = $Progress/Fill

@onready var progress_backdrop = $Progress/BackDrop

@export var TableValues = {}

@export var ProgressPercent = 0

const progress_bar_length = 1000
const progress_bar_width = 75
	
	
func _ready():
	
	progress_backdrop.custom_minimum_size = Vector2(progress_bar_length, progress_bar_width)
	
	
func _process(_delta):
	
	scoreboard.visible = Input.is_action_pressed("tab")
	progress_fill.custom_minimum_size.x = progress_bar_length * clampf(ProgressPercent, 0.0, 1.0)

	names_text.text = ""
	times_text.text = ""
	
	for key in TableValues:
		names_text.text += "\n" + str(key)
	
	for value in TableValues.values():
		times_text.text += "\n" + "%3.2f" % value
		
	
