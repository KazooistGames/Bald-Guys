extends Node3D


enum item_types {
	brick = 0,
	block = 1,
	boulder = 2,	
}

const item_paths = [
	"res://Scenes/geometry_dynamic/brick/brick.tscn",
	"res://Scenes/geometry_dynamic/block/block.tscn",
	"res://Scenes/geometry_dynamic/boulder/boulder.tscn"
	]
	

@onready var spawner = $MultiplayerSpawner

var all_items = {}


func _ready():
	
	for path in item_paths:
		spawner.add_spawnable_scene(path)
		
		
func spawn_single(item_index, spawn_point):

	var path = item_paths[item_index]
	print ("dropping single ", path) 
	var prefab = load(path)
	var new_item = prefab.instantiate()
	add_child(new_item, true)
	new_item.position = spawn_point
	
		
func spawn_field(item_index, rows, columns, spacing, spawn_point):
	
	var path = item_paths[item_index]
	print ("dropping ", rows, "x", columns, " ", path) 
	var prefab = load(path)
	
	for row_num in range(rows):
		var z_offset = (row_num - rows / 2.0) * spacing
		
		for col_num in range(columns):
			var x_offset = (col_num - columns / 2.0) * spacing
			var new_item = prefab.instantiate()
			add_child(new_item, true)
			new_item.position = spawn_point + Vector3(x_offset, 0, z_offset)
			
			if not all_items.has(path):
				all_items[path] = []
				
			all_items[path].append(new_item)
			
			
func get_items(item_index):
	
	var path = item_paths[item_index]
	
	if all_items.has(path):
		return all_items[path]
	else:
		return [] 
			

			
func clear_items(item_index):
	
	var items = get_items(item_index)
	
	for item in items:
		item.queue_free()
	
	all_items[item_paths[item_index]].clear()
	
	

func clear_all_items():
	
	for items in all_items.values():
		
		for item in items:
			item.queue_free()
	
	all_items = {}


