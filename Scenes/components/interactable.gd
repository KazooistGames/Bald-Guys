extends Area3D

signal start(node)

signal stop(node)

@export var interactions = []

@export var radius = 0.75

@onready var collider = $CollisionShape3D

var space_state

func _ready():
	
	add_to_group("interactables")
	body_entered.connect(check_interaction)
	body_exited.connect(remove_interaction)


func _process(delta):
	
	collider.shape.radius = radius


func _physics_process(delta):
	
	pass
	

func check_interaction(node):
	
	print("DETECTED: ", node)
	
	if not node:
		return
		
	elif interactions.find(node) >= 0:
		print("already present: ", node)
		
	elif has_line_of_sight(node):
		start.emit(node)
		interactions.append(node)
		

func remove_interaction(node):
	
	var index = interactions.find(node)
	
	if index >= 0:
		interactions.remove_at(index)
		
		print("LOST: ", node)
		

func has_line_of_sight(target_node):
	
	space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, target_node.global_position)
	query.exclude = [self, self.get_parent_node_3d()]
	query.collision_mask = 0b1011
	query.hit_from_inside = true
	var result = space_state.intersect_ray(query)
	
	if result == {}:
		return false
		
	elif result.collider == target_node:
		print("I SEE: ", result.collider)
		return true
	
	
	
	
