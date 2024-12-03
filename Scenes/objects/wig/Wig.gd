
extends RigidBody3D

@export var HAIR_COLOR : Color:
	
	get:
		return HAIR_COLOR
		
	set(value):
		HAIR_COLOR = value
		if not mesh: return
		var material = mesh.get_surface_override_material(0)
		material.albedo_color = value
		material.emission = value
		mesh.set_surface_override_material(0, material)


@export var radius = 0.25

@onready var mesh = $MeshInstance3D

@onready var collider = $CollisionShape3D

@onready var interactable = $Interactable

@onready var synchronizer = $MultiplayerSynchronizer

@export var AUTHORITY_POSITION = Vector3.ZERO

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
	
	mesh.mesh.radius = radius
	mesh.mesh.height = radius * 2
	collider.shape.radius = radius
	var material = mesh.get_surface_override_material(0)
	
	if strobing_enabled:
		material.emission_energy_multiplier = 4 + 4 * abs(sin(strobing_phase))
		strobing_phase += delta
	
	else:
		material.emission_energy_multiplier = 8


func getRandomHairColor():
	var rng = RandomNumberGenerator.new()

	var colorBase = rng.randf_range(0.0, 200.0 )
	
	var maxShift = (255.0 - colorBase) / 3.0
	var redShift = rng.randf_range(0.0, maxShift)
	
	var greenShift = rng.randf_range(0.0, redShift )
	
	var r = (colorBase + redShift)/255.0
	var g = (colorBase + greenShift)/255.0
	var b = colorBase/255.0
	
	HAIR_COLOR = Color(r, g, b)


func toggle_strobing(enable):
	strobing_enabled = enable
		
	
	
