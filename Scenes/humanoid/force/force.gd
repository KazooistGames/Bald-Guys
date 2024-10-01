extends Area3D

@onready var collider = $CollisionShape3D
@export var pivotOffset = Vector3.ZERO

func push():
	var collidingNodes = get_overlapping_bodies()
	for node in collidingNodes:
		var disposition = node.global_position - (global_position + pivotOffset)
		node.apply_impulse(3, disposition.normalized())
