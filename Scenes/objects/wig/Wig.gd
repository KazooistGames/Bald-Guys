extends RigidBody3D

@export var HAIR_COLOR : Color:
	
	get:
		return HAIR_COLOR
		
	set(value):
		HAIR_COLOR = value
		var model = $MeshInstance3D
		var material = model.get_surface_override_material(0)
		material.albedo_color = value
		model.set_surface_override_material(0, material)


@export var radius = 0.25

@onready var mesh = $MeshInstance3D

@onready var collider = $CollisionShape3D

@onready var interactable = $Interactable

@onready var synchronizer = $MultiplayerSynchronizer


func _enter_tree():
	
	add_to_group("wigs")
	contact_monitor = true
	max_contacts_reported = 10
	
func _ready():
	
	if not is_multiplayer_authority(): 
		return
		
	getRandomHairColor()


func _process(_delta):
	
	mesh.mesh.radius = radius
	mesh.mesh.height = radius * 2
	collider.shape.radius = radius
	

func getRandomHairColor():
	
	var rng = RandomNumberGenerator.new()
	var colorBase = rng.randf_range(0.0, 200.0 ) / 255
	var redShift = rng.randf_range(0.0, colorBase / 3.0) / 255
	var greenShift = rng.randf_range(0.0, redShift ) / 255
	HAIR_COLOR = Color(colorBase + redShift, colorBase + greenShift, colorBase)


	
	
