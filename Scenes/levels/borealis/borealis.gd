extends WorldEnvironment


#	"ZSF" = zero / span / frequency
#	used with fluctuating variables

const fog_light_energy_zsf = Vector3(0.5, 0.1, 3)

const fog_density_zsf = Vector3(0.0075, 0.0075, 13)

const fog_height_zsf = Vector3(0.75, 0.25, 31)
const fog_height_wiggle_zsf = Vector3(0.0, 0.10, 0.5)
const fog_height_density_zsf = Vector3(1.0, 0.5, 23)

const ambient_red_zsf = Vector3(0.35, 0.20, 7)
const ambient_green_zsf = Vector3(0.35, 0.20, 11)
const ambient_blue_zsf = Vector3(0.35, 0.20, 13)
const ambient_energy_zsf = Vector3(0.65, 0.3, 1)

const light_tilt_zsf = Vector3(-90, 15, 37)
const light_angle_zsf = Vector3(180, 180, 31)

const geometry_metallic_zsf = Vector3(0.5, 0.5, 47)
const geometry_roughness_zsf = Vector3(0.5, 0.5, 43)

const postprocessing_material = preload("res://Materials/post_processing.tres")
var geometry_static_material = preload("res://Materials/geometry_static.tres")
var geometry_material = preload("res://Materials/geometry.tres")
#const wall_circuits = preload("res://Materials/wall.material")


@onready var directional_light = $DirectionalLight3D

@onready var timer = randi()

	
func _process(delta):
	
	if not multiplayer.has_multiplayer_peer():
		pass
		
	elif not is_multiplayer_authority():
		return
		
	timer += delta
	set_environment_phase.rpc(timer)	
	
	#update post processing shader to use the directional lights actual point direction in its highlight/lowlight calculation
	var light_direction = Vector3(cos(directional_light.rotation.y), directional_light.rotation.x, sin(directional_light.rotation.y)).normalized()
	postprocessing_material.set_shader_parameter("light_direction", light_direction)
	
	
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

	#environment.volumetric_fog_emission_energy = get_zsf_instant(timer, fog_density_zsf)	
	environment.ambient_light_color = Color(ambient_red, ambient_green, ambient_blue)
	environment.ambient_light_energy = get_zsf_instant(timer, ambient_energy_zsf)
	
	geometry_material.metallic = get_zsf_instant(phase, geometry_metallic_zsf)
	geometry_material.roughness = get_zsf_instant(phase, geometry_roughness_zsf)
	geometry_static_material.metallic = geometry_material.metallic
	geometry_static_material.roughness = geometry_material.roughness	
	
	var x = get_zsf_instant(phase, light_tilt_zsf)
	var y = get_zsf_instant(phase, light_angle_zsf)
	directional_light.rotation_degrees = Vector3(x, y, 0)
	
	
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
