extends Node3D

class_name World

# Override this in the scene. Forest is 1
@export var world_id: int = 0
@export var container: Node3D
@export var spawner: MultiplayerSpawner

var char_scene = preload('res://assets/PlayerCharacter/PlayerCharacterScene.tscn')

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	spawner.set_spawn_function(handle_player_spawn)


# CRITICAL: NOT USED
# TODO: Better typing? Is it always Variant for this?
# data: 
# peer_id: int - the peer id
func handle_player_spawn(spawn_payload: Variant):
	if spawn_payload.world_id == world_id:
		var new_player: CharacterBody3D = char_scene.instantiate()
		new_player.name = str(spawn_payload.player_id)
		new_player.position = Vector3(randi_range(-2, 2), 0.8, randi_range(-2, 2)) * 5
		return new_player
	return false
	
