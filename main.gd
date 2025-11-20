extends Node

# TODO: remove the sync here and just rpc down the list to all players.
# Rename this ndoe to "Network" 
class_name Main

signal signal_server_info

var peer := ENetMultiplayerPeer.new()

var PORT = 9999
var IP_ADDRESS = '127.0.0.1' 

@onready var snow_scene = preload("res://worlds/snow.tscn")
@onready var forest_scene = preload("res://worlds/forest.tscn")
@onready var char_scene = preload('res://assets/PlayerCharacter/PlayerCharacterScene.tscn')

@onready var menu = $Menu
@onready var server_info = $ServerInfo

## Updated by server as a list
var current_players: Dictionary = {}

# NOTE: You can have different node trees, but if you have a server
# running both worlds, you will need positional offset as well!
@export var server_worlds_enabled: bool = true

var current_world: WORLD_OPTIONS = WORLD_OPTIONS.SNOW

# TODO: organize this by proper godot standard
enum WORLD_OPTIONS { 
	SNOW,
	FOREST
}

@onready var world_scenes: Array[Resource] = [snow_scene, forest_scene]

func _ready() -> void:
	add_to_group('Main')
	get_window().transparent = OS.has_feature('server')
	get_window().transparent_bg = OS.has_feature('server')
	
	if OS.has_feature('server'):
		host_game()
	else:
		menu.button_forest.pressed.connect(func(): join_game(WORLD_OPTIONS.FOREST))
		menu.button_snow.pressed.connect(func(): join_game(WORLD_OPTIONS.SNOW))
		server_info.queue_free()
		
func host_game():
	menu.queue_free()
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(on_peer_disconnected)
	#multiplayer.peer_connected.connect(on_peer_connected)

	# TODO: Make "worlds" a resource & have them link to a scene, so they can have additional properties
	# And instantiate themselves
	if server_worlds_enabled:
		var snow_world = snow_scene.instantiate()
		var forest_world = forest_scene.instantiate()
		add_child(snow_world, true)
		add_child(forest_world, true)

func join_game(world_to_join: WORLD_OPTIONS = current_world):
	if peer.get_connection_status() == peer.ConnectionStatus.CONNECTION_CONNECTED:		
		join_world_in_progress(world_to_join)
	else:
		peer.create_client(IP_ADDRESS, PORT)
		multiplayer.connected_to_server.connect(on_client_connected)
		multiplayer.peer_disconnected.connect(on_server_closed)
		multiplayer.multiplayer_peer = peer
		current_world = world_to_join
		menu.hide()

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
	
	sync_current_players.rpc(current_players)
	add_player_to_game(player_peer_id, world)

# TODO: more efficient with add / remove rather than replace
# add peer, remove peer
@rpc("authority", 'call_remote', 'reliable')
func sync_current_players(new_current_players):
	current_players = new_current_players


# NOTE: Not used. The player must request to be added rather than on connect.
#func on_peer_connected(id: int):
	#print("SERVER: peer connected " + str(id))
	#add_player_to_game(id)
	
func on_peer_disconnected(id):
	current_players.erase(id)
	remove_player_from_game.rpc(id)
	sync_current_players.rpc(current_players)	
	signal_server_info.emit()
	
# NOTE: Only called on the server.
func add_player_to_game(id_to_add: int, world: WORLD_OPTIONS):
	var has_id = id_to_add in get_tree().get_nodes_in_group('Players').map(func(node): int(node.name))
	if has_id == true:
		return

	# NOTE: Add the new peer to the server. 
	# INFO: OPTIONAL. If the Sync returns false for id == 1, no server instance is needed. Can be commented out.
	if server_worlds_enabled: 
		var server_worlds = get_tree().get_nodes_in_group('Worlds')
		var new_player: CharacterBody3D = char_scene.instantiate()
		new_player.name = str(id_to_add)
		new_player.position = Vector3(randi_range(-2, 2), 0.8, randi_range(-2, 2)) * 5
		server_worlds[world].add_child(new_player, true)
	
	# NOTE: This emulates a custom spawner that's targeted using rpc_id()
	for player in current_players.values():
		if player.world_id == world and player.peer_id in multiplayer.get_peers():
			# Add the new peer to the existing players
			add_player_to_world.rpc_id(player.peer_id, id_to_add)
			# Add the pre-existing peers (except self) to the new one
			if player.peer_id != id_to_add:
					add_player_to_world.rpc_id(id_to_add, player.peer_id)

	signal_server_info.emit()

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
	if get_tree().get_nodes_in_group('Worlds').size() == 0:
		add_child(world_scenes[world].instantiate(), true)
	var world_scene = get_tree().get_first_node_in_group('Worlds')
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
	menu.hide()
	
var try_reparent = false
	
## Any peer calls this _to the server_ (id 1) to kick off the process
## themselves from the current players for visibility purposes.
# TODO: Try the reparent tactic, clean up
@rpc('any_peer')
func request_move_to_world(world: WORLD_OPTIONS):
	if try_reparent:
		var player_peer_id: int = multiplayer.get_remote_sender_id()	
		current_players.erase(player_peer_id)
		#remove_player_from_game_with_reparent(player_peer_id)
		# TODO: manually add, reparent, then enable visibility... lotta work
	else:
		var player_peer_id: int = multiplayer.get_remote_sender_id()	
		current_players.erase(player_peer_id)
		remove_player_from_game.rpc(player_peer_id)
		respond_to_move_world.rpc_id(player_peer_id, world)

	sync_current_players.rpc(current_players)

# called on the client, from the server (authority).
@rpc('authority')
func respond_to_move_world(world: WORLD_OPTIONS):
	# This timeout helps avoid updates from incoming peers who think we're still visible
	# TODO: Figure out how to remove
	get_tree().get_first_node_in_group('Worlds').queue_free()
	await get_tree().create_timer(0.15).timeout
	current_world = world
	request_world.rpc_id(1, world)
	
# called on the client, from the server (authority).
#@rpc('authority')
#func respond_to_move_world_using_new_peer(world: WORLD_OPTIONS):
	## NOTE: This is the cleanest way for the local player to leave a world 
	## Close the connection & create a new one. 
	## As long as all the paths for joining are rock solid
	#multiplayer.multiplayer_peer.close()
 #
	## Now that we are no longer online, clean up the old world 
	## (and any remaining players, it's safe to do so!)
	#get_tree	().get_first_node_in_group('Worlds').queue_free()
	#
	## Set our local current_world to the desired new world
	#current_world = world
#
	## Re-Join, similar to the join_game() command above
	## This will fire off the "connected_to_server" signal
	## The remote clients will recieve it, and add the player, including self!	
	#var new_peer = ENetMultiplayerPeer.new()
	#new_peer.create_client(IP_ADDRESS, PORT)
	#multiplayer.multiplayer_peer = new_peer
	
# Return ids used to rpc_id it for each player in the world (and server?)
func get_players_in_world(world: WORLD_OPTIONS = current_world) -> Array[int]:
	if current_players.size() == 0:
		return []

	var players_in_world: Array[int] = []

	if server_worlds_enabled:
		players_in_world.append(1)

	for player in current_players.values():
		if player.peer_id != multiplayer.get_unique_id() and player.world_id == world and multiplayer.get_peers().has(player.peer_id):
			players_in_world.append(player.peer_id)

	#return result 
	##if main.current_players.has(id) and main.current_players[id].world_id == main.current_world
	#var players_in_world = main.current_players.values().filter(func(player): return player.world_id == main.current_world)
	#

	#print("WORLD TIME", players_in_world)
	return players_in_world
