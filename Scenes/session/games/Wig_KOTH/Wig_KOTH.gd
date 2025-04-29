extends Node3D

enum HillState {
	idle,
	crawling,
	climbing,
	falling
}
@export var hill_state : HillState = HillState.idle

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
@onready var floorCast : RayCast3D = $Hill/floorCast
@onready var wallCast : RayCast3D = $Hill/wallCast

@onready var session = get_parent()

var hill_speed : float = 3.0
var hill_acceleration : float = 2.0
var hill_radius : float
var hill_velocity : Vector3 = Vector3.ZERO


func _ready():
	
	session.Started_Round.connect(start_game)
	session.Ended_Round.connect(reset_game)
	Hill.visible = false
	hill_radius = randi_range(3, 5)
	rpc_resize_hill.rpc(hill_radius) # assign random hill size
	floorCast.target_position = Vector3.FORWARD * hill_radius * 3.0 / 4.0
	wallCast.target_position = Vector3.FORWARD * hill_radius * 1.0 / 3.0
	Hill.position = Vector3(0, hill_radius * 0.9, 0)
	

func _process(delta):
	
	session.HUD.modify_nameplate("WIG", "visible", Hill.visible)
	session.HUD.update_nameplate("HILL", Hill.global_position, "HILL")	
	var scoring_players = get_players_in_hill()
	var indicator_color = Color.GREEN_YELLOW if scoring_players.size() == 0 else Color.ORANGE_RED
	session.HUD.modify_nameplate("HILL", "theme_override_colors/font_color", indicator_color)

	

func _physics_process(delta):
	
	Hill.rotate(Vector3.UP, PI * delta / 30.0)	

	if not is_multiplayer_authority():
		return
		
	var scoring_players = get_players_in_hill()
	
	match State: # GAME STATE MACHINE
			
		GameState.reset:
			pass
			
		GameState.starting:	
			pass
	
		GameState.playing:
			
			for humanoid in scoring_players:
				
				var screenname = session.get_humanoids_screenname(humanoid)
				
				if Scores.has(screenname):
					Scores[screenname] += delta
					
				else:
					Scores[screenname] = 0

			var target_velocity = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(Hill.rotation.y)) * hill_speed
			
			if wallCast.is_colliding():  #we are hitting a wall, begin climbing and make sure we stick to wall
				hill_velocity = hill_velocity.move_toward(Vector3.UP * hill_speed, hill_acceleration * delta)
				hill_state = HillState.climbing				
				
			elif floorCast.is_colliding(): #walk while we are on the ground		
				hill_velocity = hill_velocity.move_toward(target_velocity, hill_acceleration * delta)
				hill_state = HillState.crawling
				
			else: #falling!
				#hill_velocity = hill_velocity.move_toward(target_velocity, hill_acceleration * delta)
				#hill_velocity += Vector3.DOWN * 4.9 * delta
				hill_velocity = hill_velocity.move_toward(Vector3.DOWN * hill_speed * 1.5, hill_acceleration * delta)
				hill_state = HillState.falling
			
			Hill.position += hill_velocity * delta
			var bounds = map_size / 2.0 - hill_radius / 4.0
			Hill.position.x = clampf(Hill.position.x, -bounds, bounds)
			Hill.position.y = clampf(Hill.position.y,  hill_radius / 4.0, map_size - hill_radius / 4.0)
			Hill.position.z = clampf(Hill.position.z, -bounds, bounds)
			rpc_reposition_hill.rpc(Hill.position)	
			
		GameState.finished:			
			pass

	
@rpc("call_local", "reliable")	
func rpc_resize_hill(radius):
	hill_collider.shape.radius = radius
	hill_mesh.mesh.radius = hill_collider.shape.radius
	hill_mesh.mesh.height = hill_collider.shape.radius * 2.0
	print("Hill radius: ", radius)
	
	
@rpc("call_local", "reliable")	
func rpc_reposition_hill(coordinates):
	
	Hill.position = coordinates


func get_players_in_hill() -> Array[Node3D]:
	
	if not Hill: 
		return []
	
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
		Hill.visible = false	
		session.HUD.find_child("Progress").visible = false			
		State = GameState.reset
		session.HUD.remove_nameplate("HILL")
		
		for value in session.Client_Screennames.values():
			Scores[value] = 0
			
	
@rpc("call_local", "reliable")
func rpc_play():
	
	session.HUD.add_nameplate("HILL", "HILL")
	session.HUD.modify_nameplate("HILL", "theme_override_colors/font_color", Color.GREEN_YELLOW)
	session.HUD.modify_nameplate("HILL", "theme_override_font_sizes/font_size", 24)
	Hill.visible = true
	
	if is_multiplayer_authority(): 
		State = GameState.playing
		
		for value in session.Client_Screennames.values():
			Scores[value] = 0
				
	
@rpc("call_local", "reliable")
func rpc_finish():
	
	if is_multiplayer_authority(): 
		State = GameState.finished
		Hill.visible = false
		session.HUD.remove_nameplate("HILL")

	
	

