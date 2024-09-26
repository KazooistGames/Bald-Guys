extends Area3D

signal start(node)

signal stop(node)

@export var interactions = []

@export var radius = 0.5

@onready var collider = $CollisionShape3D


func _ready():
	add_to_group("interactables")
	body_entered.connect(check_interaction)
	body_exited.connect(remove_interaction)


func _process(delta):
	collider.shape.radius = radius


func check_interaction(node):
	
	if not node:
		return
		
	elif has_line_of_sight(node.global_position):
		start.emit(node)
		interactions.add(node)
		

func remove_interaction(node):
	
	var index = interactions.find(node)
	
	if index >= 0:
		interactions.remove_at(index)
		

func has_line_of_sight(position):
	return true
