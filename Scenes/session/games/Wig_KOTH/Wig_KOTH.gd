extends Node3D

enum GameState {
	reset,
	starting,
	playing,
	finished
}

@export var State = GameState.reset

@export var Scores : Dictionary = {}
@export var Goal : float

@export var hill_extents : Vector3 = Vector3.ONE
@export var map_size : float = 50
@export var raycast_height : int = 30

@onready var Hill = $Hill
@onready var raycast = $RayCast3D
@onready var hill_collider : CollisionShape3D = $Hill/CollisionShape3D
@onready var hill_mesh : MeshInstance3D = $Hill/MeshInstance3D

@onready var session = get_parent()

var reassignment_timer : float = 0.0
var reassignment_period : float = 60.0


func _ready():
	
	session.Started_Round.connect(start)
	session.Ended_Round.connect(reset)


func _process(delta):
		
	match State: # GAME STATE MACHINE
			
		GameState.reset:
			pass
			
		GameState.starting:	
			pass
	
		GameState.playing:	
			session.HUD.update_nameplate("HILL", Hill.global_position, "HILL")	
			
			if reassignment_timer >= reassignment_period:
				reassignment_timer -= reassignment_period
				move_hill()
			else:
				reassignment_timer += delta
			
		GameState.finished:			
			pass

func move_hill():
	
	var bounds = map_size / 2.0
	var random_coords : Vector2 = Vector2(randi_range(0, bounds), randi_range(0, bounds))
	
	raycast.global_position = Vector3(random_coords.x, raycast_height, random_coords.y)
	raycast.force_raycast_update()
	var geometry = raycast.get_collider()
	var point = raycast.get_collision_point()
	var new_position : Vector3
	
	if geometry is AnimatableBody3D:
		new_position = Vector3(geometry.position.x, point.y, geometry.position.z) 
		hill_collider.shape.size.y = 3.0 * max(geometry.position.y - point.y, 1.0)
		
	else:
		new_position = point
		hill_collider.shape.size.y = 3.0
		
	Hill.position = new_position
	hill_collider.shape.size.x = randi_range(3, 8)
	hill_collider.shape.size.z = randi_range(3, 8)
	
	hill_mesh.mesh.size = hill_collider.shape.size
	

func start():
	
	if is_multiplayer_authority(): 
		rpc_start.rpc()
	
	
func reset():
	
	if is_multiplayer_authority(): 
		rpc_reset.rpc()	
		
		
	
@rpc("call_local", "reliable")
func rpc_start():
	
	if is_multiplayer_authority(): 
		rpc_reset()
		State = GameState.starting
	

@rpc("call_local", "reliable")
func rpc_reset():
	
	if is_multiplayer_authority(): 	
		session.HUD.find_child("Progress").visible = false			
		State = GameState.reset

	
@rpc("call_local", "reliable")
func rpc_play():
	
	session.HUD.add_nameplate("HILL", "HILL")
	session.HUD.modify_nameplate("HILL", "theme_override_colors/font_color", Color.GREEN_YELLOW)
	session.HUD.modify_nameplate("HILL", "theme_override_font_sizes/font_size", 24)
	move_hill()
	
	if is_multiplayer_authority(): 
		
		for value in session.Client_Screennames.values():
			Scores[value] = 0
		State = GameState.playing
	
	
@rpc("call_local", "reliable")
func rpc_finish():
	
	if is_multiplayer_authority(): 
		State = GameState.finished

	
	

