extends CanvasLayer


@onready var PSA = $PSA/Label
var psaTTL = 1

@export var TableValues = {}

@export var ProgressPercent = 0

const progress_bar_length = 1000
const progress_bar_width = 75
	
	
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
	
