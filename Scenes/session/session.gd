extends Node3D

const Humanoid_Prefab = preload("res://Scenes/humanoid/humanoid.tscn")

const SessionState = {
	Hub = 0,
	Level = 1,
}

@export var State = SessionState.Hub

@export var Commissioned = false

@export var Humanoids = []

@onready var humanoidSpawner = $MultiplayerSpawner

signal Created_Player_Humanoid

func _ready():
	humanoidSpawner.spawned.connect(signal_to_handoff_player_humanoid)


func _process(_delta):

	Humanoids = get_tree().get_nodes_in_group("humanoids")


@rpc("authority", "call_local")
func Commission(peer_ids):
	
	for peer_id in peer_ids:
		create_player_humanoid(peer_id)
		
	Commissioned = true


func create_player_humanoid(peer_id):
	
	var available_spawns = get_tree().get_nodes_in_group("spawns")
	var new_peer_humanoid = Humanoid_Prefab.instantiate()
	new_peer_humanoid.name = str(peer_id)
	new_peer_humanoid.position = available_spawns.pick_random().transform.origin
	Humanoids.append(new_peer_humanoid)
	add_child(new_peer_humanoid)
	signal_to_handoff_player_humanoid(new_peer_humanoid)
	#Created_Player_Humanoid.emit(new_peer_humanoid.get_path(), peer_id)


func signal_to_handoff_player_humanoid(node):
	
	Created_Player_Humanoid.emit(node)




