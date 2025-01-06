extends MultiplayerSynchronizer

@export var AUTHORITY_ORIGIN = Vector3.ZERO
@export var AUTHORITY_BASIS = Basis.IDENTITY

@export var lerp_val = 0.25


var parent


func _ready():
	
	parent = get_parent()
	
	if not parent_is_valid():
		queue_free()
		

func _physics_process(_delta):
	
	if not parent_is_valid():
		queue_free()
		
	elif not multiplayer.has_multiplayer_peer():
		pass
		
	elif is_multiplayer_authority():
		AUTHORITY_ORIGIN = parent.transform.origin
		AUTHORITY_BASIS = parent.transform.basis
		
	else:
		parent.transform.basis = AUTHORITY_BASIS
		
		if parent.position.distance_to(AUTHORITY_ORIGIN) > 1.0:
			parent.transform.origin = AUTHORITY_ORIGIN	
		else:
			parent.transform.origin = parent.transform.origin.lerp(AUTHORITY_ORIGIN, lerp_val)


func parent_is_valid():
	
	if parent != null:
		return true
	elif parent is Node3D:
		return true
	else:
		return false

	
