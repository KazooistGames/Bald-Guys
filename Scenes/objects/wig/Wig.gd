
extends RigidBody3D

const radius_speed = 0.05

@export var HAIR_COLOR : Color:
	
	get:
		return HAIR_COLOR
		
	set(value):
		HAIR_COLOR = value
		#light.light_color = value
		if not mesh: return
		material = mesh.get_surface_override_material(0)
		material.albedo_color = value
		material.emission = value
		mesh.set_surface_override_material(0, material)
		
var AUTHORITY_POSITION := Vector3.ZERO
var radius := 0.15
var actual_radius := 0.15	

@onready var Dawn = $Dawn
@onready var Drop = $Drop
@onready var mesh = $MeshInstance3D
@onready var collider = $CollisionShape3D
@onready var interactable = $Interactable
@onready var synchronizer = $MultiplayerSynchronizer
@onready var light = $OmniLight3D
@onready var material = mesh.get_surface_override_material(0)


var strobing_enabled = false
var strobing_phase = 0


func _enter_tree():
	
	add_to_group("wigs")
	contact_monitor = true
	max_contacts_reported = 10
	actual_radius = radius
	
	
func _ready():
	
	if not is_multiplayer_authority(): 
		return
		
	getRandomHairColor()


func _process(delta):
	
	light.light_color = HAIR_COLOR
	material.emission_energy_multiplier = 1 + actual_radius
	light.light_energy = actual_radius * 2
	
	if mesh.mesh.radius != radius:
		var updated_radius = move_toward(mesh.mesh.radius, radius, delta * radius_speed)
		
		if updated_radius >= 0.0:
			mesh.mesh.radius = updated_radius
			mesh.mesh.height = updated_radius * 2
			collider.shape.radius = updated_radius
			
		actual_radius = updated_radius
		
	else:
		actual_radius = radius
		
	#if strobing_enabled:
#
		#strobing_phase += delta
	#
	#else:
		#material.emission_energy_multiplier = 0.5
		

func getRandomHairColor():
	
	var rng = RandomNumberGenerator.new()
	
	var colorBase = rng.randf_range(0.0, 0.5)
	var maxShift = (1.0 - colorBase)
	var redShift = randf() * maxShift
	var greenShift = rng.randf_range(0.0, redShift )

	var r = colorBase + redShift
	var g = colorBase + greenShift
	var b = colorBase
	
	HAIR_COLOR = Color(r, g, b)
	print("Wig Color: ", HAIR_COLOR)


func toggle_strobing(enable):
	
	strobing_enabled = enable
		
