extends Node3D

@onready var radiation = $radiation

@onready var boop = $boop

var bpm = 10
var boop_timer = 0.0
var boop_period = 60
var boop_burst_size = 2
var boop_burst_count = 0
var boop_burst_period = 0.75
var boop_burst_timer = 0.0


func _ready():
	
	radiation.play()
	
	
func _process(delta):
	
	if boop_burst_count >= boop_burst_size:
		boop_timer -= boop_period
		boop_period = 60.0/bpm
		boop_burst_count = 0
		boop_burst_timer = 0.0
		boop_burst_size = randi_range(1, 4)
	
	elif boop_burst_timer >= boop_burst_period:
		boop.play()
		boop_burst_timer -= boop_burst_period
		boop_burst_count += 1
		
	elif boop_timer >= boop_period:
		boop_burst_timer += delta
		
	else:
		boop_timer += delta 
		


	
	
