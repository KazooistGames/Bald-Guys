extends Node3D

const Humanoid_Prefab = preload("res://Scenes/humanoid/humanoid.tscn")

const SessionState = {
	Hub = 0,
	Level = 1,
}

@export var State = SessionState.Level

@onready var Hub = $Hub

@onready var Level = $Level

@export var Commissioned = false

@export var Humanoids = []

@onready var humanoidSpawner = $MultiplayerSpawner

signal Created_Player_Humanoid

func _ready():
	humanoidSpawner.spawned.connect(signal_to_handoff_player_humanoid)


func _process(_delta):

	Humanoids = get_tree().get_nodes_in_group("humanoids")

@rpc("authority", "call_local")
func switch_to_hub():
	
	if State == SessionState.Hub:
		return
		
	else:
		State = SessionState.Hub
		
		for humanoid in Humanoids:
			humanoid.position = get_random_spawn()
		
		
@rpc("authority", "call_local")
func switch_to_level():
	
	if State == SessionState.Level:
		return
		
	else:
		State = SessionState.Level
		
		for humanoid in Humanoids:
			humanoid.position = get_random_spawn()


@rpc("authority", "call_local")
func Commission(peer_ids):
	
	for peer_id in peer_ids:
		create_player_humanoid(peer_id)
		
	Commissioned = true


func get_random_spawn():
	
	var all_spawns = get_tree().get_nodes_in_group("spawns")
	var valid_spawns = []
	var parent = Hub if State == SessionState.Hub else Level
	
	#for child in parent.get_children():
		#
		#if child.is_in_group("spawns"):
			#valid_spawns.append(child)
	
	for spawn in all_spawns:
		
		if spawn.is_ancestor_of(parent):
			valid_spawns.append(spawn)
		
		elif spawn.find_parent(parent.name):
			valid_spawns.append(spawn)
	
	return valid_spawns.pick_random().global_position

func create_player_humanoid(peer_id):
	
	var new_peer_humanoid = Humanoid_Prefab.instantiate()
	new_peer_humanoid.name = str(peer_id)
	new_peer_humanoid.position = get_random_spawn()
	Humanoids.append(new_peer_humanoid)
	add_child(new_peer_humanoid)
	signal_to_handoff_player_humanoid(new_peer_humanoid)
	#Created_Player_Humanoid.emit(new_peer_humanoid.get_path(), peer_id)


func signal_to_handoff_player_humanoid(node):
	
	Created_Player_Humanoid.emit(node)




