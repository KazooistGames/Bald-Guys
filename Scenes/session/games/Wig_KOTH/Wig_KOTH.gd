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
	playing,
	finished
}

@export var State = GameState.reset
@export var map_size : float = 50
@export var Scores : Dictionary = {}
@export var Goal : float = 10
@export var Hill_Size : float = 4.0 

@onready var Hill = $Hill
@onready var hill_collider : CollisionShape3D = $Hill/CollisionShape3D
@onready var hill_mesh : MeshInstance3D = $Hill/MeshInstance3D
@onready var core_mesh : MeshInstance3D = $Hill/MeshInstance3D2
@onready var floorCast : RayCast3D = $Hill/floorCast
@onready var wallCast : RayCast3D = $Hill/wallCast
@onready var session = get_parent()
@onready var synchronizer = $MultiplayerSynchronizer

var hill_speed : float = 0.75
var hill_velocity : Vector3 = Vector3.ZERO
var hill_acceleration : float = 2.0
var hill_phase = 0.0

var wig_radii : Vector2 = Vector2(0.15, 0.45)
var wig_start_offset = Vector3(0, 0.2, -0.025)
var wig_end_offset = Vector3(0, 0.5, -0.075)

signal GameOver

func _ready():

	Hill.visible = false
	hill_collider.disabled = true
	hill_collider.shape.radius = 0.01
	hill_mesh.mesh.radius = 0.01
	hill_mesh.mesh.height = 0.01
	core_mesh.mesh.radius = 0.01
	core_mesh.mesh.height = 0.01
	Hill.position = Vector3(0, map_size / 2.0, 0)
	hill_phase = randi()


func _process(delta):
	
	resize_hill(Hill_Size, delta)	
	session.HUD.update_nameplate("HILL", Hill.global_position, "HILL")	
	var scoring_players : Array[Node3D] = get_players_in_hill()
	var indicator_color = Color.GREEN_YELLOW if scoring_players.size() == 0 else Color.ORANGE_RED
	session.HUD.modify_nameplate("HILL", "theme_override_colors/font_color", indicator_color)
	
	if State == GameState.playing:
		session.HUD.find_child("Progress").visible = scoring_players.has(session.local_humanoid()) and Hill.visible
	

func _physics_process(delta):
		
	if not multiplayer.has_multiplayer_peer():
		pass
	elif not is_multiplayer_authority():
		return	
	
	match State: # GAME STATE MACHINE
			
		GameState.reset:
			pass
			
	
		GameState.playing:
			Hill_Size = 4.0
			var scoring_players = get_players_in_hill()
			hill_phase += delta / 100.0
			Hill.rotation.y = sin(5 * hill_phase) + sin(hill_phase * PI)

			for humanoid in scoring_players:
				
				var screenname = session.get_humanoids_screenname(humanoid)
				
				if not Scores.has(screenname):
					Scores[screenname] = 0
					
				elif Scores[screenname] < Goal:
					Scores[screenname] += delta
					rpc_adjust_wig_size.rpc(humanoid.get_path(), Scores[screenname]/Goal)
					
				else:
					GameOver.emit()

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
				
				if Hill.global_position.y - collision_point.y < Hill_Size / 4.0:
					target_direction += Vector3.UP
				
				hill_state = HillState.crawling
				
			else: #falling!
				hill_velocity = hill_velocity.move_toward(Vector3.DOWN * hill_speed * 1.5, 4.9 * delta)
				hill_state = HillState.falling
			
			var step = hill_acceleration * delta
			hill_velocity = hill_velocity.move_toward(target_direction.normalized() * hill_speed, step)
			Hill.position += hill_velocity * delta
			var bounds = map_size / 2.0 - Hill_Size / 4.0
			Hill.position.x = clampf(Hill.position.x, -bounds, bounds)
			Hill.position.y = clampf(Hill.position.y,  Hill_Size / 4.0, bounds)
			Hill.position.z = clampf(Hill.position.z, -bounds, bounds)
			
		GameState.finished:			
			Hill_Size = 0.0

	
func resize_hill(new_radius, time_elapsed):
	
	if hill_collider.shape.radius != new_radius:
		hill_collider.shape.radius = move_toward(hill_collider.shape.radius, new_radius, time_elapsed)
		hill_mesh.mesh.radius = hill_collider.shape.radius
		hill_mesh.mesh.height = hill_collider.shape.radius * 2.0
		core_mesh.mesh.radius = hill_mesh.mesh.radius / 10.0
		core_mesh.mesh.height = hill_mesh.mesh.height / 10.0
		floorCast.target_position = Vector3.FORWARD * Hill_Size * 3.0 / 4.0
		wallCast.target_position = Vector3.FORWARD * Hill_Size * 3.0 / 4.0
	elif new_radius == 0:
		Hill.visible = false
		hill_collider.disabled = true


func get_players_in_hill() -> Array[Node3D]:
	
	if not Hill: 
		return []
	
	var all_bodies : Array[Node3D] = Hill.get_overlapping_bodies()
	var players : Array[Node3D] = []
	
	for body in all_bodies:
		
		if not body.is_in_group("humanoids"):
			pass
		elif not session.bearers.has(body):
			pass
		else:	
			players.append(body)
			
	return players
		
		
@rpc("call_local", "reliable")
func rpc_adjust_wig_size(path_to_bearer, progress : float):
	
	var bearer = get_node(path_to_bearer)
	var index = session.bearers.find(bearer)
	var wig = session.wigs[index]
	wig.radius = lerp(wig_radii.x, wig_radii.y, progress)
	var remote = bearer.find_child("*RemoteTransform*", true, false)
	remote.position = lerp(wig_start_offset, wig_end_offset, progress)
	

@rpc("call_local", "reliable")
func rpc_reset():
	
	session.HUD.remove_nameplate("HILL")
	session.HUD.find_child("Progress").visible = false		
	
	if is_multiplayer_authority(): 
		Scores = {}
		Hill.visible = false
		Hill_Size = 0.0
		State = GameState.reset
		
		for value in session.Client_Screennames.values():
			Scores[value] = 0
			
	
@rpc("call_local", "reliable")
func rpc_play():
	
	Hill.visible = true
	hill_collider.disabled = false
	session.HUD.add_nameplate("HILL", "HILL")
	session.HUD.modify_nameplate("HILL", "theme_override_colors/font_color", Color.GREEN_YELLOW)
	session.HUD.modify_nameplate("HILL", "theme_override_font_sizes/font_size", 24)
	session.HUD.set_progress_label("Growing Hair...")
	
	if is_multiplayer_authority(): 
		session.HUD.set_psa.rpc("Grow your Hair!")
		State = GameState.playing
		
		for value in session.Client_Screennames.values():
			Scores[value] = 0
				
	
@rpc("call_local", "reliable")
func rpc_finish():
	
	session.HUD.remove_nameplate("HILL")
	
	if is_multiplayer_authority(): 
		session.HUD.find_child("Progress").visible = false
		State = GameState.finished
		session.HUD.remove_nameplate("HILL")


func handle_player_joining(client_id) -> void:
	
	pass
	

func handle_player_leaving(client_id) -> void:
	
	pass
