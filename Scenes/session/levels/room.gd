extends Node3D

@export var Next_Size : int = 50
@export var Current_Size : int = 50
@export var Resizing : bool = false

@onready var floor : Node3D = $floor
@onready var ceiling : Node3D = $ceiling
@onready var wall : Node3D = $wall
@onready var wall2 : Node3D = $wall2
@onready var wall3 : Node3D = $wall3
@onready var wall4 : Node3D = $wall4

@onready var spawns : Array[Node] = $spawns.get_children()

@onready var wall_mesh = preload("res://Scenes/geometry_static/Wall/wall_mesh.tres")
@onready var wall_collider = preload("res://Scenes/geometry_static/Wall/wall_collider.tres")

var resize_period : float = 3.0


func _process(delta:float) -> void:
	
	if Resizing:
		adjust_room_to_size(Current_Size)
		
	elif Next_Size != Current_Size:
		Resizing = true
		var tween : Tween = create_tween()
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.tween_property(self, "Current_Size", Next_Size, resize_period)
		tween.tween_callback(func(): Resizing = false)
		
		
func adjust_room_to_size(desired_size : int) -> void:
	
	ceiling.position.y = desired_size
	wall.position = Vector3(-desired_size/2.0, desired_size/2.0, 0.0)
	wall2.position = Vector3(desired_size/2.0, desired_size/2.0, 0.0)
	wall3.position = Vector3(0.0, desired_size/2.0, -desired_size/2.0)
	wall4.position = Vector3(0.0, desired_size/2.0, desired_size/2.0)
	wall_mesh.size = Vector2.ONE * desired_size
	wall_collider.size = Vector3(desired_size, 1.0, desired_size)
	
	for index in range(spawns.size()):
		var spawn : Node3D = spawns[index]
		var radius : float = desired_size * 0.4
		var phase = (2.0 * PI) / (index + 1.0)
		spawn.position = Vector3(cos(phase), 1.0, sin(phase)) * radius
