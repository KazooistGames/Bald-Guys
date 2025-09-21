extends MultiplayerSynchronizer


@export var AUTHORITY_ORIGIN = Vector3.ZERO
@export var AUTHORITY_BASIS = Basis.IDENTITY
@export var Authority_Angular_Velocity = Vector3.ZERO
@export var Authority_Linear_Velocity = Vector3.ZERO

@export var lerp_val = 0.25

var parent : RigidBody3D


func _ready():
	
	parent = get_parent()
	
	if not parent_is_valid():
		queue_free()
		
	synchronized.connect(predictive_correction)
		

func _physics_process(_delta):
	
	if not parent_is_valid():
		queue_free()
		
	elif not multiplayer.has_multiplayer_peer():
		pass

		
	elif is_multiplayer_authority():
		AUTHORITY_ORIGIN = parent.transform.origin
		AUTHORITY_BASIS = parent.transform.basis
		Authority_Angular_Velocity = parent.angular_velocity
		Authority_Linear_Velocity = parent.linear_velocity
		
	elif not parent.freeze:
		
		parent.transform.basis = AUTHORITY_BASIS
		parent.angular_velocity = Authority_Angular_Velocity
		
		if parent.position.distance_to(AUTHORITY_ORIGIN) > 1.0:
			parent.transform.origin = AUTHORITY_ORIGIN	
		else:
			parent.transform.origin = parent.transform.origin.lerp(AUTHORITY_ORIGIN, lerp_val)

		if parent.linear_velocity.distance_to(Authority_Linear_Velocity) > 1.0:
			parent.linear_velocity = Authority_Linear_Velocity
		else:
			parent.linear_velocity = parent.linear_velocity


func predictive_correction():

	var step_size = Lag.SERVER_PING
	var gravity_step = Vector3.UP * 9.8 * step_size * parent.gravity_scale
	Authority_Linear_Velocity -= gravity_step
	AUTHORITY_ORIGIN += Authority_Linear_Velocity * step_size
	

func parent_is_valid():
	
	if parent == null:
		return false
	elif parent is RigidBody3D:
		return true
	else:
		return false

	
