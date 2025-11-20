class_name DebugTools

var instance_index: int = -1
var instance_socket: TCPServer 

func detect_instance_index() -> void:
	instance_socket = TCPServer.new()
	
	for index: int in 20:
		if instance_socket.listen(5000 + index) == OK:
			instance_index = index - 1
			break

func update_instance_window_rect(window: Window, max_instances_count: int, title_bar_height: int = 30) -> void:
	var screen_rect: Rect2 = Rect2(DisplayServer.screen_get_usable_rect())
	
	var cols: int = ceili(sqrt(max_instances_count))
	var rows: int = ceili(float(max_instances_count) / cols)
	
	var width: float = screen_rect.size.x / cols
	var height: float = screen_rect.size.y / rows
	var origin: Vector2 = screen_rect.position + Vector2(
		(int(float(instance_index) / cols)) * width,
		(instance_index % cols) * height
		)
	
	window.size = Vector2(width, height - title_bar_height)
	window.position = origin + Vector2.DOWN * title_bar_height
