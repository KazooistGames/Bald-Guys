extends MultiplayerSynchronizer

@export var AUTHORITY_ORIGIN = Vector3.ZERO
@export var AUTHORITY_BASIS = Basis.IDENTITY

@export var Authority_Angular_Velocity = Vector3.ZERO


var parent


func _ready():
	
	parent = get_parent()
	
	if parent == null:
		queue_free()
		
	elif not parent is RigidBody3D:
		queue_free() 


func _physics_process(delta):
	
	if parent == null:
		queue_free()
		
	elif not parent is RigidBody3D:
		queue_free() 
		
	elif not multiplayer.has_multiplayer_peer():
		pass
		
	elif is_multiplayer_authority():
		AUTHORITY_ORIGIN = parent.transform.origin
		AUTHORITY_BASIS = parent.transform.basis
		Authority_Angular_Velocity = parent.angular_velocity
		
	else:
		parent.transform.basis = AUTHORITY_BASIS
		Authority_Angular_Velocity = Authority_Angular_Velocity
		if parent.position.distance_to(AUTHORITY_ORIGIN) > 1.0:
			parent.transform.origin = parent.transform.origin.lerp(AUTHORITY_ORIGIN, 0.5)
			
		else:
			parent.transform.origin = parent.transform.origin.lerp(AUTHORITY_ORIGIN, 0.25)

		



	
