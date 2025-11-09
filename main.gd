extends Node3D

# TODO: remove the sync here and just rpc down the list to all players.
# Rename this ndoe to "Network" 
class_name Main

var peer := ENetMultiplayerPeer.new()

var PORT = 9999
var IP_ADDRESS = '127.0.0.1' 

@onready var snow_scene = preload("res://worlds/snow.tscn")
@onready var forest_scene = preload("res://worlds/forest.tscn")

var char_scene = preload('res://assets/PlayerCharacter/PlayerCharacterScene.tscn')

# NOTE: The server tracks this via a multiplayer syncronizer on main.
@export var server_worlds_enabled: bool = false
var current_world: WORLD_OPTIONS = WORLD_OPTIONS.SNOW

enum WORLD_OPTIONS { 
	SNOW,
	FOREST
}

@onready var world_scenes: Array[Resource] = [snow_scene, forest_scene]

@onready var menu = %Menu

func _ready() -> void:
	add_to_group('Main')
	
	if OS.has_feature('server'):
		host_game()
	else:	
		%ButtonJoinSnow.pressed.connect(func(): join_game(WORLD_OPTIONS.SNOW))
		%ButtonJoinForest.pressed.connect(func(): join_game(WORLD_OPTIONS.FOREST))

func host_game():
	# NOTE: needs per-pixel transparency
	#get_window().transparent = true
	#get_window().transparent_bg = true

	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(on_peer_disconnected)
	#multiplayer.peer_connected.connect(on_peer_connected)

	# TODO: Make "worlds" a resource & have them link to a scene, so they can have additional properties
	# And instantiate themselves
	if server_worlds_enabled:
		var snow_world = snow_scene.instantiate()
		var forest_world = forest_scene.instantiate()

		%Worlds.add_child(snow_world)
		%Worlds.add_child(forest_world)

	%ServerInfo.show()
	%Menu.queue_free()

func join_game(world_to_join: WORLD_OPTIONS = current_world):
	if peer.get_connection_status() == peer.ConnectionStatus.CONNECTION_CONNECTED:		
		join_world_in_progress(world_to_join)
	else:
		peer.create_client(IP_ADDRESS, PORT)
		multiplayer.connected_to_server.connect(on_client_connected)
		multiplayer.peer_disconnected.connect(on_server_closed)
		multiplayer.multiplayer_peer = peer
		current_world = world_to_join
		%Menu.hide()



@export var current_players: Dictionary = {}

# Set up in _ready(): multiplayer.connected_to_server.connect(on_client_connected)
func on_client_connected():
	print("CLIENT: client connected to server: ", multiplayer.get_unique_id())
	request_world.rpc_id(1, current_world)

# This happens only on the server ( always called with rpc_id(1) )
@rpc('any_peer') # Allow any peer to trigger it when joining
func request_world(world: WORLD_OPTIONS):
	var player_peer_id: int = multiplayer.get_remote_sender_id()

	# When this changes, all the peers also get it.
	current_players[player_peer_id] = {
		'peer_id': player_peer_id, 
		'world_id': world
	}
	add_player_to_game(player_peer_id, world)
















# NOTE: Not used. The player must request to be added rather than on connect.
#func on_peer_connected(id: int):
	#print("SERVER: peer connected " + str(id))
	#add_player_to_game(id)
	
func on_peer_disconnected(id):
	if id in multiplayer.get_peers():
		print("SERVER: peer disconnected " + str(id))
		current_players.erase(id)
		remove_player_from_game.rpc(id)
	
	update_server_display_text()
	
# NOTE: Only called on the server.
func add_player_to_game(id_to_add: int, world: WORLD_OPTIONS):
	var has_id = id_to_add in get_tree().get_nodes_in_group('Players').map(func(node): int(node.name))
	if has_id == true:
		return

	# NOTE: Add the new peer to the server. 
	# INFO: OPTIONAL. If the Sync returns false for id == 1, no server instance is needed. Can be commented out.
	if server_worlds_enabled: 
		var server_world: World = %Worlds.get_child(world)
		var new_player: CharacterBody3D = char_scene.instantiate()
		new_player.name = str(id_to_add)
		new_player.position = Vector3(randi_range(-2, 2), 0.8, randi_range(-2, 2)) * 5
		server_world.add_child(new_player)
	
	# NOTE: This emulates a custom spawner that's targeted using rpc_id()
	for player in current_players.values():
		if player.world_id == world and player.peer_id in multiplayer.get_peers():
			# Add the new peer to the existing players
			add_player_to_world.rpc_id(player.peer_id, id_to_add)
			# Add the pre-existing peers (except self) to the new one
			if player.peer_id != id_to_add:
					add_player_to_world.rpc_id(id_to_add, player.peer_id)

	update_server_display_text()

	# TODO: Instruct update visibility for manaully in this step.
	# TODO: MultiplayerSpawner doesn't really work since it _always_ calls on all peers.
	# You'd have to have a minimal dummy world mounted at least mimic the top level tree
	# Could work, just have to drop players into nothing and turn off sync visibility
	#var spawn_payload = {
		#'player_id': id,
		#'world_id': world
	#}
	#%Worlds.get_child(world).spawner.spawn(spawn_payload)
	
# Called from server down to clients on signal. Also called locally to clean up server.
@rpc("authority", 'call_local')
func remove_player_from_game(id: int):
	var players: Array[Node] = get_tree().get_nodes_in_group('Players')
	var player_to_remove = players.find_custom(func(item): return item.name == str(id))
	if player_to_remove != -1:
		players[player_to_remove].queue_free()

@rpc("authority", 'call_local')
func remove_player_from_game_with_reparent(id: int):
	# detect if we are the one being removed!
	var skip_self = id == multiplayer.get_unique_id()
	# rest of the func
	var players: Array[Node] = get_tree().get_nodes_in_group('Players')
	var player_to_remove = players.find_custom(func(item): return item.name == str(id))
	if player_to_remove != -1 and not skip_self:
		players[player_to_remove].queue_free()

	
# Server calls this to clients who have a world...
@rpc("authority")
func add_player_to_world(id, world: WORLD_OPTIONS = current_world):
	if %Worlds.get_child_count() == 0:
		%Worlds.add_child(world_scenes[world].instantiate())
	var world_scene = %Worlds.get_child(0)
	var new_player: CharacterBody3D = char_scene.instantiate()
	new_player.name = str(id)
	new_player.position = Vector3(randi_range(-2, 2), 0.8, randi_range(-2, 2)) * 5
	world_scene.add_child(new_player, true)

func on_server_closed(id):
	if id == 1:
		multiplayer.multiplayer_peer = null
		for player in get_tree().get_nodes_in_group("Players"):
			player.queue_free()
			# TODO: Go back to Menu


func join_world_in_progress(world: WORLD_OPTIONS):
	if current_world == world:
		return

	request_move_to_world.rpc_id(1, world)
	%Menu.hide()
	
var try_reparent = false
	
# TODO: Try the reparent tactic, clean up
@rpc('any_peer')
func request_move_to_world(world: WORLD_OPTIONS):
	if try_reparent:
		var player_peer_id: int = multiplayer.get_remote_sender_id()	
		current_players.erase(player_peer_id)
		remove_player_from_game_with_reparent(player_peer_id)
		# TODO: manually add, reparent, then enable visibility... lotta work
	else:
		var player_peer_id: int = multiplayer.get_remote_sender_id()	
		current_players.erase(player_peer_id)
		remove_player_from_game.rpc(player_peer_id)
		respond_to_move_world.rpc_id(player_peer_id, world)

# called on the client, from the server (authority).
@rpc('authority')
func respond_to_move_world(world: WORLD_OPTIONS):
	# This timeout helps avoid updates from incoming peers who think we're still visible
	# TODO: Figure out how to remove
	await get_tree().create_timer(0.08).timeout
	%Worlds.get_child(0).queue_free()
	current_world = world
	request_world.rpc_id(1, world)

# called on the client, from the server (authority).
@rpc('authority')
func respond_to_move_world_using_new_peer(world: WORLD_OPTIONS):
	# NOTE: This is the cleanest way for the local player to leave a world 
	# Close the connection & create a new one. 
	# As long as all the paths for joining are rock solid
	multiplayer.multiplayer_peer.close()
 
	# Now that we are no longer online, clean up the old world 
	# (and any remaining players, it's safe to do so!)
	%Worlds.get_child(0).queue_free()
	
	# Set our local current_world to the desired new world
	current_world = world

	# Re-Join, similar to the join_game() command above
	# This will fire off the "connected_to_server" signal
	# The remote clients will recieve it, and add the player, including self!	
	var new_peer = ENetMultiplayerPeer.new()
	new_peer.create_client(IP_ADDRESS, PORT)
	multiplayer.multiplayer_peer = new_peer


func update_server_display_text():
	var snow_ids = Global.get_players_in_world(WORLD_OPTIONS.SNOW)
	var forest_ids = Global.get_players_in_world(WORLD_OPTIONS.FOREST)

	%LabelBoxSnow.get_children().map(func(item): item.queue_free())
	%LabelBoxForest.get_children().map(func(item): item.queue_free())

	for id in snow_ids:
		var new_label = Label.new()
		new_label.text = str(id)
		new_label.name = str(id)
		%LabelBoxSnow.add_child(new_label, true)

	for id in forest_ids:
		var new_label = Label.new()
		new_label.text = str(id)
		new_label.name = str(id)
		%LabelBoxForest.add_child(new_label, true)
