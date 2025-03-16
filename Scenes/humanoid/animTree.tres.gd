extends AnimationTree

const WalkState = {
	WALKING = "walking",
	RUNNING = "running",
}
@export var WALK_STATE = WalkState.WALKING

@export var walkAnimPlaybackScalar = 1.65
@export var walkAnimBlendScalar = 2.0

var maxBlendVal = 1
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func updateWalking(topSpeed, velocity, is_back_pedaling):
	maxBlendVal = clamp(lerp(0, 1, topSpeed/walkAnimBlendScalar), 0, 1)
	var translationalVelocity = Vector2(velocity.x, velocity.z)
	var blend =  (1-translationalVelocity.length()/topSpeed)*maxBlendVal
	set("parameters/velocity/blend_amount", clamp(blend, 0, 1))
	set("parameters/WalkSpeed/scale", -walkAnimPlaybackScalar if is_back_pedaling else walkAnimPlaybackScalar)	
	set("parameters/MoveState/transition_request", "walking")
	set("parameters/WalkStance/transition_request", WALK_STATE)
	
func updateFalling(velocity):
	set("parameters/MoveState/transition_request", "falling")
	var jumpDeltaScale = gravity*2 if velocity.y > 0 else gravity/1.5
	var jumpCrestScale = lerp(1, 0, abs(velocity.y)/jumpDeltaScale)
	set("parameters/Jump/blend_position", jumpCrestScale)
