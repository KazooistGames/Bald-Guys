extends RigidBody3D

@export var radius = 0.25

@onready var mesh = $MeshInstance3D

@onready var collider = $CollisionShape3D

@onready var interactable = $Interactable

@onready var synchronizer = $MultiplayerSynchronizer


func _enter_tree():
	
	add_to_group("wigs")
	contact_monitor = true
	max_contacts_reported = 10


func _process(_delta):
	
	mesh.mesh.radius = radius
	mesh.mesh.height = radius * 2
	collider.shape.radius = radius
	

	


	
	
