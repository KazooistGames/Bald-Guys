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

@onready var Hill = $Hill
@onready var hill_collider : CollisionShape3D = $Hill/CollisionShape3D
@onready var hill_mesh : MeshInstance3D = $Hill/MeshInstance3D
@onready var raycast : RayCast3D = $RayCast3D

@onready var session = get_parent()

var reassignment_timer : float = 0.0
var reassignment_period : float = 10.0


func _ready():
	
	session.Started_Round.connect(start_game)
	session.Ended_Round.connect(reset_game)


func _process(delta):
	reassignment_period = 5.0
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
				
				var scoring_players = get_players_in_hill()
				
				for humanoid in scoring_players:
					
					var screenname = session.get_humanoids_screenname(humanoid)
					
					if Scores.has(screenname):
						Scores[screenname] += delta
						
					else:
						Scores[screenname] = 0
						
				var indicator_color = Color.GREEN_YELLOW if scoring_players.size() == 0 else Color.ORANGE_RED
				session.HUD.modify_nameplate("HILL", "theme_override_colors/font_color", indicator_color)
			
		GameState.finished:			
			pass


func move_hill():
	
	hill_collider.shape.height = 3.0
	hill_collider.shape.radius = randi_range(3, 8)
	var bounds = (map_size / 2.0) - hill_collider.shape.radius
	var random_coords : Vector2 = Vector2(randf_range(0, bounds), randf_range(0, bounds))
	raycast.global_position = Vector3(random_coords.x, map_size, random_coords.y)
	raycast.force_update_transform()
	raycast.force_raycast_update()
	var geometry = raycast.get_collider()
	var new_position = raycast.get_collision_point()		
	print("new Hill at : ", new_position)
	Hill.position = new_position

	
	hill_mesh.mesh.top_radius = hill_collider.shape.radius
	hill_mesh.mesh.bottom_radius = hill_collider.shape.radius
	hill_mesh.mesh.height = hill_collider.shape.height


func get_players_in_hill() -> Array[Node3D]:
	
	var all_bodies : Array[Node3D] = Hill.get_overlapping_bodies()
	var players : Array[Node3D] = []
	
	for body in all_bodies:
		if body.is_in_group("humanoids"):
			players.append(body)
			
	return players
		
		
func start_game():
	
	if is_multiplayer_authority(): 
		rpc_reset.rpc()
		rpc_start.rpc()
	
	
func reset_game():
	
	if is_multiplayer_authority(): 
		rpc_reset.rpc()	
		Scores = {}
		Hill.visible = false
		
	
@rpc("call_local", "reliable")
func rpc_start():
	
	Hill.visible = true
	
	if is_multiplayer_authority(): 
		State = GameState.starting
		
		for value in session.Client_Screennames.values():
			Scores[value] = 0
	

@rpc("call_local", "reliable")
func rpc_reset():
	
	if is_multiplayer_authority(): 	
		session.HUD.find_child("Progress").visible = false			
		State = GameState.reset
		
		for value in session.Client_Screennames.values():
			Scores[value] = 0
			
	
@rpc("call_local", "reliable")
func rpc_play():
	
	session.HUD.add_nameplate("HILL", "HILL")
	session.HUD.modify_nameplate("HILL", "theme_override_colors/font_color", Color.GREEN_YELLOW)
	session.HUD.modify_nameplate("HILL", "theme_override_font_sizes/font_size", 24)
	move_hill()
	
	if is_multiplayer_authority(): 
		State = GameState.playing
		
		for value in session.Client_Screennames.values():
			Scores[value] = 0
				
	
@rpc("call_local", "reliable")
func rpc_finish():
	
	if is_multiplayer_authority(): 
		State = GameState.finished

	
	

