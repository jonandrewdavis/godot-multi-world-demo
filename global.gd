extends Node

var debug_tools: DebugTools

var main: Main

func _init() -> void:
	if OS.is_debug_build():
		debug_tools = DebugTools.new()
		debug_tools.detect_instance_index()

func _ready() -> void:
	if OS.is_debug_build():
		debug_tools.update_instance_window_rect(get_window(), 4)

	await get_tree().create_timer(0.3).timeout
	main = get_tree().get_first_node_in_group('Main')

# Return ids used to rpc_id it for each player in the world (and server?)
func get_players_in_world(world: Main.WORLD_OPTIONS = main.current_world) -> Array[int]:
	if not main:	
		return []

	if main.current_players.size() == 0:
		return []

	var players_in_world: Array[int] = []

	if main.server_worlds_enabled:
		players_in_world.append(1)

	for player in main.current_players.values():
		if player.peer_id != multiplayer.get_unique_id() and player.world_id == world and multiplayer.get_peers().has(player.peer_id):
			players_in_world.append(player.peer_id)

	#return result 
	##if main.current_players.has(id) and main.current_players[id].world_id == main.current_world
	#var players_in_world = main.current_players.values().filter(func(player): return player.world_id == main.current_world)
	#

	#print("WORLD TIME", players_in_world)
	return players_in_world
