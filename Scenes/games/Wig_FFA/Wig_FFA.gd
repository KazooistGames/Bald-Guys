extends Node3D

const wig_prefab = preload("res://Scenes/objects/wig/Wig.tscn")

var Wig : Node3D

var Bearer : Node3D

@export var Goal_Time = 60

@export var Bearer_Times = {}

@onready var wig_remote = $RemoteTransform3D

@onready var HUD = $HUD

var local_player_name

enum GameState {
	reset,
	starting,
	playing,
	finished
}

@export var State = GameState.reset

signal Starting()
signal Playing()
signal Finished()
signal Resetting()

var countDown_timer = 0
var countDown_value = 0

func _ready():
	
	local_player_name = str(multiplayer.get_unique_id())
	
	
func _process(delta):
			
	if not Wig:
		Wig = get_node_or_null("Wig")

	HUD.TableValues = Bearer_Times
	
	if not is_multiplayer_authority():
		pass
		
	elif State == GameState.reset:
		pass
		
	elif State == GameState.starting:
		
		if countDown_value <= 0:
			rpc_play.rpc()
			
		elif countDown_timer > 1:
			countDown_timer = 0
			countDown_value -= 1
			HUD.set_psa.rpc(str(countDown_value))
			
		else:
			countDown_timer += delta
	
	elif State == GameState.playing:
		
		if not Bearer:
			pass
			
		elif Bearer_Times.has(Bearer.name):
			Bearer_Times[Bearer.name] += delta
			
			if Bearer_Times[Bearer.name] >= Goal_Time:
				HUD.set_psa.rpc("Winner: " + str(Bearer.name), -1)
				rpc_finish.rpc()
		
		else:
			Bearer_Times[Bearer.name] = delta
			
	elif State == GameState.finished:
		pass
		
	if Bearer:
		HUD.find_child("Progress").visible = local_player_name == Bearer.name
			
	else:
		HUD.find_child("Progress").visible = false
		
	if Bearer_Times.has(local_player_name):	
		var accumulated_time = Bearer_Times[local_player_name]
		HUD.ProgressPercent = clampf(accumulated_time/Goal_Time, 0.0, 1.0)


func dawn_wig(node):
	
	if not Wig:
		pass
		
	elif not node.is_in_group("humanoids"):
		pass
		
	elif not Bearer:
		Wig.interactable.gained_interaction.disconnect(dawn_wig)
		node.ragdolled.connect(drop_wig)
		
		move_wig_remote_controller.rpc(node.find_child("*head").get_path())
		toggle_wig_mount.rpc(true)
		
		set_wig_bearer.rpc(node.get_path())
		print("dawned ", node)

		
func drop_wig():
	
	Wig.interactable.gained_interaction.connect(dawn_wig)
	Bearer.ragdolled.disconnect(drop_wig)
	
	var current_position = Wig.global_position
	
	move_wig_remote_controller.rpc(Bearer.get_parent().get_path())
	toggle_wig_mount.rpc(false)
	
	Wig.global_position = current_position
	Wig.linear_velocity = Bearer.velocity * 1.5 + Vector3(0, 3, 0)

	set_wig_bearer.rpc(null)
	print("Dropped")
	
	
@rpc("call_local")
func toggle_wig_mount(value):
	if not Wig: return
	Wig.collider.disabled = value
	Wig.freeze = value


@rpc("call_local")
func move_wig_remote_controller(path_to_new_parent):
	
	wig_remote.get_parent().remove_child(wig_remote)
	var new_parent = get_node(path_to_new_parent)
	
	if not new_parent: 
		return
		
	new_parent.add_child(wig_remote)


@rpc("call_local")
func set_wig_bearer(path_to_new_bearer):
	
	if path_to_new_bearer == null:
		Bearer = null
		wig_remote.remote_path = ""
		#Wig.synchronizer.replication_config.property_set_replication_mode("Wig:position", 1)
		
	else:	
		Bearer = get_node(path_to_new_bearer)
		wig_remote.remote_path = Wig.get_path()
		wig_remote.position = Vector3(0, 0.275, -.075)
		#Wig.synchronizer.replication_config.property_set_replication_mode("Wig:position", 0)
				

@rpc("call_local")
func rpc_reset():
	
	if not is_multiplayer_authority(): return
	
	HUD.find_child("Progress").visible = false
	#HUD.set_psa.rpc("")
	
	if Bearer:
		drop_wig()
		Bearer = null

	if Wig:
		Wig.queue_free()
		Wig = null
	
	Bearer_Times = {}
	State = GameState.reset
	Resetting.emit()
	

@rpc("call_local")
func rpc_start():
	
	if not is_multiplayer_authority(): return

	rpc_reset()
	countDown_value = 10
	HUD.set_psa.rpc(str(countDown_value))
	State = GameState.starting
	Starting.emit()
	
	
@rpc("call_local")
func rpc_play():
	
	if not is_multiplayer_authority(): return
	
	Bearer_Times = {}
	Wig = wig_prefab.instantiate()
	add_child(Wig)
	Wig.global_position = Vector3(0, 20, 0)
	Wig.interactable.gained_interaction.connect(dawn_wig)
	
	State = GameState.playing
	Playing.emit()
	
	
@rpc("call_local")
func rpc_finish():
	
	if not is_multiplayer_authority(): return
	
	if Bearer:
		Bearer.ragdolled.disconnect(drop_wig)
		
	State = GameState.finished
	Finished.emit()

	
	

