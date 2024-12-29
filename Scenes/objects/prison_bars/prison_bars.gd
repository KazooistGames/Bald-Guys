extends Node3D


var bars = []

var bars_locked = 0

var extend_index = 0
var retract_index = 0

const retract_speed = 1.0
const extend_speed = 2.0

const deadband = 0.25

var last_retract = -1


func _ready():
	
	bars.append($bar1)
	bars.append($bar2)
	bars.append($bar3)
	bars.append($bar4)


func _process(delta):
	
	bars_locked = 0
	
	for bar in bars:

		bar.position.x = max(bar.position.x, 0.0)
		
		if bars.find(bar) == retract_index:
			pass		
		elif bar.position.x <= bar.top_height:
			bars_locked += 1		
		else:
			bar.position.x -= delta * extend_speed
			bar.rerender()

	if retract_index < 0:
		
		if bars_locked >= bars.size():
			retract_index = randi_range(last_retract, bars.size())
			retract_index = retract_index % bars.size()
		
	elif bars[retract_index].bottom_position.length() <= deadband:
		bars[retract_index].position.x = max(bars[retract_index].position.x, 0.0)
		last_retract = retract_index
		retract_index = -1		
		
	else:
		bars[retract_index].position.x += delta * retract_speed
		bars[retract_index].rerender()
		

	
	
