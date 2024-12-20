extends Node3D

@onready var radiation = $radiation

@onready var boop = $boop

var notes = [1.0, 1.1, 1.0, 0.84]
var note_index = 0

var bpm = 3
var boop_timer = 0.0
var boop_period = 10


func _ready():
	
	radiation.play()
	
	
func _process(delta):
	
	boop_timer += delta 
	boop_period = 60.0/bpm
	
	if boop_timer >= boop_period:
		boop_timer -= boop_period
		boop.play()
		


	
	
