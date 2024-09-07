extends WorldEnvironment

var timer = 0.0

#"MSF" = Minimum - Span - Frequency
#used with fluctuating variables

const fog_light_energy_zsf = Vector3(1.0, 1.0, 200)

const fog_density_zsf = Vector3(0.025, 0.025, 150)

const fog_height_zsf = Vector3(0, 3, 100)

const fog_height_density_zsf = Vector3(0.025, 0.025, 50)

func _ready():
	pass # Replace with function body.


func _process(delta):
	timer += delta
	environment.fog_light_energy = get_msf_instant(timer, fog_light_energy_zsf)
	environment.fog_density = get_msf_instant(timer, fog_density_zsf)
	environment.fog_height = get_msf_instant(timer, fog_height_zsf)
	environment.fog_height_density = get_msf_instant(timer, fog_height_density_zsf)
	print(environment.fog_light_energy, environment.fog_density, environment.fog_height, environment.fog_height_density )
	
func get_msf_instant(phase, zsf, offset = 0):
	return zsf.x + zsf.y * sin(offset + phase/zsf.z/2*PI) 
