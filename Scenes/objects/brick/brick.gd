extends RigidBody3D

@export var AUTHORITY_POSITION = Vector3.ZERO

func _ready():
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 5
	body_entered.connect(process_hit)
	
		
func _integrate_forces(state):

	if is_multiplayer_authority():
		AUTHORITY_POSITION = state.transform.origin	
		
	elif position.distance_to(AUTHORITY_POSITION) > 1.0:
		state.transform.origin = state.transform.origin.lerp(AUTHORITY_POSITION, 0.25)
		
	else:
		state.transform.origin = state.transform.origin.lerp(AUTHORITY_POSITION, 0.05)
		
		
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
			
	print("boink ", magnitude)
	node.apply_central_impulse(magnitude * direction)
