extends RigidBody3D

signal interacting

@export var radius = 0.25

@onready var mesh = $MeshInstance3D

@onready var collider = $CollisionShape3D

@onready var triggerCollider = $Area3D/CollisionShape3D

@onready var interactArea = $Area3D

@export var wearer : Node3D

func _enter_tree():
	
	add_to_group("wigs")
	contact_monitor = true
	max_contacts_reported = 10


func _process(_delta):
	
	mesh.mesh.radius = radius
	mesh.mesh.height = radius * 2
	collider.shape.radius = radius
	triggerCollider.shape.radius = radius * 2
	

	


	
	
