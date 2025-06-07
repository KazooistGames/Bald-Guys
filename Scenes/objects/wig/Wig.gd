
extends RigidBody3D

const radius_speed = 0.25

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
		
@export var AUTHORITY_POSITION = Vector3.ZERO
@export var radius = 0.15
	
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
	
	
func _ready():
	
	if not is_multiplayer_authority(): 
		return
		
	getRandomHairColor()


func _process(delta):
	
	light.light_color = HAIR_COLOR
	material.emission_energy_multiplier = 1 + radius
	light.light_energy = radius * 2
	
	if mesh.mesh.radius != radius:
		mesh.mesh.radius = move_toward(mesh.mesh.radius, radius, delta * radius_speed)
		mesh.mesh.height = mesh.mesh.radius * 2
		collider.shape.radius = mesh.mesh.radius
		
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
		
