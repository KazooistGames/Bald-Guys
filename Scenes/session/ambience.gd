extends Node3D

@onready var radiation = $radiation

@onready var boop = $boop

var bpm = 10

var cycle_timer = 0.0
var cycle_period = 60

var burst_size = 2
var burst_bpm_ratio = 2.0

var boop_count = 0
var boop_period = 2.0/3.0
var boop_timer = 0.0

const echo_chance = 0.5
const echo_period_ratio = 1.0/3.0
var echo_this_boop = false

const logging = true

const new_time_sig_chance = 0.75

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
		burst_size = randi_range(2, 6)
		boop_period = cycle_period / ( burst_size * burst_bpm_ratio)
		
		if logging:
			print("burst size: ", burst_size, ", period: ", boop_period)
		
		if randf() > new_time_sig_chance:
			bpm = randi_range(1, 4) * 3
			burst_bpm_ratio = randi_range(1, 4)
			
			if logging:
				print("new time signature, bpm: ", bpm, ", burst_bpm_ratio: ", burst_bpm_ratio)
			
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
		


	
	
