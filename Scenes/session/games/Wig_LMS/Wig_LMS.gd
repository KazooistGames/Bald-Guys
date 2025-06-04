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


var wig_radii : Vector2 = Vector2(0.15, 0.45)
var wig_start_offset = Vector3(0, 0.2, -0.025)
var wig_end_offset = Vector3(0, 0.5, -0.075)

signal GameOver

func _ready():
	pass

func _process(delta):
	pass
	
	
func _physics_process(delta):
		
	if not multiplayer.has_multiplayer_peer():
		pass
	elif not is_multiplayer_authority():
		return	
	
	match State: # GAME STATE MACHINE
			
		GameState.reset:
			pass	
	
		GameState.playing:
			pass
		
		GameState.finished:			
			pass

		
		
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
