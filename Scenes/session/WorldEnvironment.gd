extends WorldEnvironment

var timer = 0.0

#"MSF" = Minimum - Span - Frequency
#used with fluctuating variables

const fog_light_energy_zsf = Vector3(6.0, 0.5, 0.5)

const fog_density_zsf = Vector3(0.02, 0.01, 3)

const fog_height_zsf = Vector3(2.0, 0.5, 10)

const fog_height_wiggle_zsf = Vector3(0.0, 0.2, 1)

const fog_height_density_zsf = Vector3(2.0, 0.75, 30)


func _process(delta):
	timer += delta
	
	environment.fog_light_energy = get_zsf_instant(timer, fog_light_energy_zsf)
	environment.fog_density = get_zsf_instant(timer, fog_density_zsf)
	environment.fog_height = get_zsf_instant(timer, fog_height_zsf) + get_zsf_instant(timer, fog_height_wiggle_zsf)
	environment.fog_height_density = get_zsf_instant(timer, fog_height_density_zsf)
	
func get_zsf_instant(phase, zsf, offset = 0):
	return zsf.x + zsf.y * sin(offset + phase/zsf.z) 
