extends Node

var debug_tools: DebugTools

func _init() -> void:
	if OS.is_debug_build():
		debug_tools = DebugTools.new()
		debug_tools.detect_instance_index()

func _ready() -> void:
	if OS.is_debug_build():
		debug_tools.update_instance_window_rect(get_window(), 4)
