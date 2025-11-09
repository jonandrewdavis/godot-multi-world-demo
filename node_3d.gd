extends Node3D

@export var server_version: String 

var local_version = '1.0'

func _ready() -> void:
	# I'm a server, I set the version & can change it when I export
	if OS.has_feature('server'):
		server_version = '1.0'
	else:
		multiplayer.connected_to_server.connect(_check_client)

func _check_client():
	await get_tree().create_timer(1.0).timeout
	print(server_version, local_version)
	if local_version != server_version:
		get_tree().quit()
