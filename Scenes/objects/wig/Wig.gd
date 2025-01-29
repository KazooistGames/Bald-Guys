
extends RigidBody3D

const beas_mote_transition = 54.65

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
		
@export var AUTHORITY_POSITION = Vector3.ZERO

@export var radius = 0.25

@onready var Dawn = $Dawn
@onready var Drop = $Drop
@onready var whispers = $Whispers
@onready var theme = $Theme

@onready var mesh = $MeshInstance3D
@onready var collider = $CollisionShape3D
@onready var interactable = $Interactable
@onready var synchronizer = $MultiplayerSynchronizer

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
	whispers.stream_paused = false
	theme.stream_paused = true

func _process(delta):
	
	mesh.mesh.radius = radius
	mesh.mesh.height = radius * 2
	collider.shape.radius = radius
	var material = mesh.get_surface_override_material(0)
	
	if strobing_enabled:
		material.emission_energy_multiplier = 1 * abs(sin(strobing_phase))
		strobing_phase += delta
	
	else:
		material.emission_energy_multiplier = 0.5
		
	if whispers.get_playback_position() >= beas_mote_transition:
		whispers.seek(0)
		
	if theme.get_playback_position() < beas_mote_transition:
		theme.seek(beas_mote_transition)
		
	theme.stream_paused = not whispers.stream_paused


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
		
