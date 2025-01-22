extends CanvasLayer

@export var TableValues = {}

@onready var nameplates = $Nameplates

@onready var PSA = $PSA/Label

var psaTTL = 1

	
	
func _process(delta):
	
	print(nameplates.get_children())

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
	
	
func place_nameplate(player_id, coordinates):
	var nameplate = nameplates.find_child(str(player_id))
	

func add_nameplate(player_id, player_name):
	
	var new_nameplate = Label.new()
	new_nameplate.name = player_id
	new_nameplate.text = player_name
	nameplates.add_child(new_nameplate)
	
	
func remove_nameplate(player_id):
	
	var nameplate = nameplates.find_child(str(player_id), false, false)
	nameplate.queue_free()
	
	
