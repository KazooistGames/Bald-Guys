extends Node3D

@onready var radiation = $radiation

@onready var boop = $boop

var bpm = 10

var cycle_timer = 0.0
var cycle_period = 60

var burst_size = 2

var boop_count = 0
var boop_period = 0.75
var boop_timer = 0.0

var echo_chance = 0.5
var echo_period_ratio = 1.0/3.0
var echo_this_boop = false


func _ready():
	
	radiation.play()
	
	
func _process(delta):
	
	if echo_this_boop:
		
		if boop_timer >= boop_period * echo_period_ratio:
			echo_this_boop = false
			boop.play()
			
		else:
			boop_timer += delta
	
	elif boop_count >= burst_size:
		cycle_timer -= cycle_period
		cycle_timer += boop_count * boop_period
		boop_count = 0
		boop_timer = 0.0
		burst_size = randi_range(1, 4)
		
		if randf() > 0.8:
			bpm = randi_range(1, 4) * 3
			
		cycle_period = 60.0/bpm
	
	elif boop_timer >= boop_period:
		boop.play()
		boop_timer -= boop_period
		boop_count += 1
		
		if randf() <= echo_chance:
			echo_this_boop = true
		
	elif cycle_timer >= cycle_period:
		boop_timer += delta
		
	else:
		cycle_timer += delta 
		


	
	
