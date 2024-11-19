extends RigidBody3D

@export var AUTHORITY_POSITION = Vector3.ZERO

func _ready():
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 5
	body_entered.connect(process_hit)
		
		
func process_hit(node):
			
	if not node:
		pass
		
	elif not node.is_in_group("humanoids"):
		pass
		
	else:
		hit_humanoid.rpc(node.get_path())
	
	
@rpc("call_local")
func hit_humanoid(node_path):

	var node = get_node(node_path)
	
	var direction = node.global_position - global_position
	var magnitude = linear_velocity.length() * mass
	var impulse = magnitude * direction
	print(impulse)
	node.apply_central_impulse(impulse)
