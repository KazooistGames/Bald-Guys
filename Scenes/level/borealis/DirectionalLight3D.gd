extends DirectionalLight3D

@export var wave_phase = 0.0
@export var wave_period = 60

@export var energy_max = 1.0
@export var energy_min = 0.0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	if not is_multiplayer_authority():
		return
	
	wave_phase += delta
	
	var raw_wave = sin (wave_phase / wave_period)
	
	var rectified_wave = abs(raw_wave)
	
	var scaled_wave = pow (rectified_wave, 0.5)
	
	var clamped_wave = clamp (scaled_wave, energy_min, energy_max)

	light_energy = clamped_wave
	
	#print(raw_wave, "   ", rectified_wave,"   ", scaled_wave, "   ", clamped_wave)
	
