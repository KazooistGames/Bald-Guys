extends WorldEnvironment

var timer = 0.0

#	"ZSF" = zero / span / frequency
#	used with fluctuating variables

const fog_light_energy_zsf = Vector3(0.5, 0.1, 0.5)

const fog_density_zsf = Vector3(0.0175, 0.015, 3)

const fog_height_zsf = Vector3(2.8, 1, 10)
const fog_height_wiggle_zsf = Vector3(0.0, 0.2, 1)
const fog_height_density_zsf = Vector3(0.40, 0.2, 30)

const ambient_red_zsf = Vector3(0.35, 0.20, 3)
const ambient_green_zsf = Vector3(0.35, 0.20, 5)
const ambient_blue_zsf = Vector3(0.35, 0.20, 7)
const ambient_energy_zsf = Vector3(0.65, 0.3, 1)

@onready var directional_light = $DirectionalLight3D

func _process(delta):
	
	if not multiplayer.has_multiplayer_peer():
		pass
		
	elif not is_multiplayer_authority():
		return
		
	timer += delta
	set_environment_phase.rpc(timer)	
	
	
func get_zsf_instant(phase, zsf, offset = 0):
	return zsf.x + zsf.y * sin(offset + phase/zsf.z) 


@rpc("call_local")
func set_environment_phase(phase):
	
	environment.fog_light_energy = get_zsf_instant(phase, fog_light_energy_zsf)
	environment.fog_density = get_zsf_instant(phase, fog_density_zsf)
	environment.fog_height = get_zsf_instant(phase, fog_height_zsf) + get_zsf_instant(phase, fog_height_wiggle_zsf)
	environment.fog_height_density = get_zsf_instant(phase, fog_height_density_zsf)
	
	var ambient_red = get_zsf_instant(phase, ambient_red_zsf)	
	var ambient_green = get_zsf_instant(phase, ambient_green_zsf)	
	var ambient_blue = get_zsf_instant(phase, ambient_blue_zsf)	

	environment.ambient_light_color = Color(ambient_red, ambient_green, ambient_blue)
	#environment.volumetric_fog_emission_energy = get_zsf_instant(timer, fog_density_zsf)
	
	environment.ambient_light_energy = get_zsf_instant(timer, ambient_energy_zsf)
	
	
@export var light_wave_period = 60
@export var light_energy_max = 1.2
@export var light_energy_min = 0.0
@rpc("call_local")
func set_light_phase(phase):
	
	var raw_wave = sin (phase / light_wave_period)
	
	var rectified_wave = abs(raw_wave)
	
	var scaled_wave = pow (rectified_wave, 0.5)
	
	var clamped_wave = clamp (scaled_wave, light_energy_min, light_energy_max)

	directional_light.light_energy = clamped_wave
	
	#print(raw_wave, "   ", rectified_wave,"   ", scaled_wave, "   ", clamped_wave)
