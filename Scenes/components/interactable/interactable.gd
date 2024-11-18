extends Area3D

signal gained_interaction(node)

signal lost_interaction(node)

@export var DEBUG = false

@export var available_interactions = []

@export var radius = 1.0

@onready var collider = $CollisionShape3D

var space_state

@onready var debug_box = $DebugBox
@onready var debug_sphere = $DebugSphere

func _ready():
	
	add_to_group("interactables")


func _process(_delta):
	debug_box.visible = DEBUG
	debug_sphere.visible = DEBUG
	collider.shape.radius = radius


func _physics_process(_delta):
	
	space_state = get_world_3d().direct_space_state
		
	var intersection_query = PhysicsShapeQueryParameters3D.new()
	intersection_query.shape = collider.shape
	intersection_query.transform = collider.global_transform
	intersection_query.collision_mask = 0b1011
	intersection_query.exclude = [self, self.get_parent_node_3d()]
	
	var intersections = space_state.collide_shape(intersection_query)
	var entry
	var exit
	var target
	var i = 0
	
	if intersections == null:
		return

	var instantaneous_interactions = []	

	while i < intersections.size():
		entry = intersections[i]
		exit = intersections[i+1]
		target = (entry + exit) / 2
		var casted_body = get_body_from_cast(target)

		if instantaneous_interactions.find(casted_body) >= 0:
			pass
	
		elif casted_body:
			instantaneous_interactions.append(casted_body)
	
		debug_box.global_position = intersections[intersections.size()-2]
		debug_sphere.global_position = intersections[intersections.size()-1]
		i += 2

	for node in instantaneous_interactions:

		if not node:
			pass

		elif available_interactions.find(node) >= 0:
			pass
			
		else:
			gained_interaction.emit(node)
			available_interactions.append(node)

			if DEBUG:
				print(self, " gained: ", node)
				
	for node in available_interactions:

		if node == null:
			pass

		elif instantaneous_interactions.find(node) < 0:

			available_interactions.remove_at(available_interactions.find(node))
			lost_interaction.emit(node)

			if DEBUG:
				print(self, " lost: ", node)


func get_body_from_cast(targets_position):
	
	var query = PhysicsRayQueryParameters3D.create(global_position, targets_position)
	query.exclude = [self, self.get_parent_node_3d()]
	query.collision_mask = 0b1011
	query.hit_from_inside = true
	var result = space_state.intersect_ray(query)
	
	if result == {}:
		return null
		
	else:
		return result.collider
		

func has_line_of_sight(target_node):
	
	var targets_position = target_node.global_position
	var query = PhysicsRayQueryParameters3D.create(global_position, targets_position)
	query.exclude = [self, self.get_parent_node_3d()]
	query.collision_mask = 0b1011
	query.hit_from_inside = true
	var result = space_state.intersect_ray(query)
	
	if result == {}:
		return true
		
	elif result.collider == target_node:
		return true
		
	else:
		print("caught by ", result.collider)
	
	
	
	
