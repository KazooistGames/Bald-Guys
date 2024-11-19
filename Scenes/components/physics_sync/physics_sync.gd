extends MultiplayerSynchronizer

@export var AUTHORITY_ORIGIN = Vector3.ZERO
@export var AUTHORITY_BASIS = Basis.IDENTITY


var parent


func _ready():
	parent = get_parent()


func _physics_process(delta):
	
	if is_multiplayer_authority():
		AUTHORITY_ORIGIN = parent.transform.origin
		AUTHORITY_BASIS = AUTHORITY_BASIS
		
	else:
		parent.transform.basis = parent.transform.basis.slerp(AUTHORITY_BASIS, 0.25)
		
		if parent.position.distance_to(AUTHORITY_ORIGIN) > 1.0:
			parent.transform.origin = parent.transform.origin.lerp(AUTHORITY_ORIGIN, 0.5)
			
		else:
			parent.transform.origin = parent.transform.origin.lerp(AUTHORITY_ORIGIN, 0.05)

		



	
