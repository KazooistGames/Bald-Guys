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
@export var Goal : float = 60

@export var hill_extents : Vector3 = Vector3.ONE
@export var map_size : float = 50

@onready var Hill = $Hill
@onready var hill_collider : CollisionShape3D = $Hill/CollisionShape3D
@onready var hill_mesh : MeshInstance3D = $Hill/MeshInstance3D
@onready var core_mesh : MeshInstance3D = $Hill/MeshInstance3D2
@onready var floorCast : RayCast3D = $Hill/floorCast
@onready var wallCast : RayCast3D = $Hill/wallCast

@onready var session = get_parent()

var hill_speed : float = 0.75
var hill_acceleration : float = 2.0
var hill_radius : float = 5.0
var hill_velocity : Vector3 = Vector3.ZERO

var phase = 0.0

func _ready():
	
	session.Started_Round.connect(start_game)
	session.Ended_Round.connect(reset_game)
	Hill.visible = false
	rpc_resize_hill.rpc(0)
	floorCast.target_position = Vector3.FORWARD * hill_radius * 3.0 / 4.0
	wallCast.target_position = Vector3.FORWARD * hill_radius * 3.0 / 4.0
	Hill.position = Vector3(0, hill_radius * 0.9, 0)
	session.HUD.set_progress_label("Growing Hair...")


func _process(delta):
	
	phase += delta / 100.0
	session.HUD.modify_nameplate("WIG", "visible", Hill.visible)
	session.HUD.update_nameplate("HILL", Hill.global_position, "HILL")	
	var scoring_players : Array[Node3D] = get_players_in_hill()
	var indicator_color = Color.GREEN_YELLOW if scoring_players.size() == 0 else Color.ORANGE_RED
	session.HUD.modify_nameplate("HILL", "theme_override_colors/font_color", indicator_color)
	session.HUD.find_child("Progress").visible = scoring_players.has(session.local_humanoid())
	

func _physics_process(delta):
	
	Hill.rotation.y = (sin(phase * 5) + sin(PI * phase)) * PI
	
	if not is_multiplayer_authority():
		return
		
	var scoring_players = get_players_in_hill()
	
	match State: # GAME STATE MACHINE
			
		GameState.reset:
			pass
			
		GameState.starting:	
			pass
	
		GameState.playing:
			
			if hill_collider.shape.radius != hill_radius:
				rpc_resize_hill.rpc(move_toward(hill_collider.shape.radius, hill_radius, 1.0 * delta))
			
			for humanoid in scoring_players:
				
				var screenname = session.get_humanoids_screenname(humanoid)
				
				if Scores.has(screenname):
					Scores[screenname] += delta
					
				else:
					Scores[screenname] = 0

			var collision_point : Vector3 = Vector3.ZERO
			var target_direction : Vector3 = Vector3.ZERO
			
			if wallCast.is_colliding():  #we are hitting a wall, begin climbing and make sure we stick to wall
				hill_state = HillState.climbing			
				collision_point = wallCast.get_collision_point()		
				target_direction = Vector3.UP
				
				if wallCast.get_collision_normal() != Vector3.ZERO:			
					target_direction += (collision_point - Hill.global_position).normalized()

			elif floorCast.is_colliding(): #walk while we are on the ground	
				collision_point = floorCast.get_collision_point()	
				target_direction = (collision_point - Hill.global_position).normalized()
				
				if Hill.global_position.y - collision_point.y < hill_radius / 4.0:
					target_direction += Vector3.UP
				
				hill_state = HillState.crawling
				
			else: #falling!
				hill_velocity = hill_velocity.move_toward(Vector3.DOWN * hill_speed * 1.5, 4.9 * delta)
				hill_state = HillState.falling
			
			hill_velocity = hill_velocity.move_toward(target_direction.normalized() * hill_speed, hill_acceleration * delta)
			Hill.position += hill_velocity * delta
			var bounds = map_size / 2.0 - hill_radius / 4.0
			Hill.position.x = clampf(Hill.position.x, -bounds, bounds)
			Hill.position.y = clampf(Hill.position.y,  hill_radius / 4.0, map_size / 2.0 - hill_radius / 4.0)
			Hill.position.z = clampf(Hill.position.z, -bounds, bounds)
			rpc_reposition_hill.rpc(Hill.position)	
			
		GameState.finished:			
			pass

	
@rpc("call_local", "reliable")	
func rpc_resize_hill(radius):
	
	hill_collider.shape.radius = radius
	hill_mesh.mesh.radius = hill_collider.shape.radius
	hill_mesh.mesh.height = hill_collider.shape.radius * 2.0
	core_mesh.mesh.radius = hill_collider.shape.radius / 10.0
	core_mesh.mesh.height = hill_mesh.mesh.height / 10.0
	
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

	
	

