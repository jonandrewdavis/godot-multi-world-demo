extends Control

var main: Main
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	main = get_parent()
	main.signal_server_info.connect(update_server_display_text)

func update_server_display_text():
	print('TODO: UPDATE SERVER DISPLAY')
	#var snow_ids = Global.get_players_in_world(main.WORLD_OPTIONS.SNOW)
	#var forest_ids = Global.get_players_in_world(main.WORLD_OPTIONS.FOREST)
#
	#%LabelBoxSnow.get_children().map(func(item): item.queue_free())
	#%LabelBoxForest.get_children().map(func(item): item.queue_free())
#
	#for id in snow_ids:
		#var new_label = Label.new()
		#new_label.text = str(id)
		#new_label.name = str(id)
		#%LabelBoxSnow.add_child(new_label, true)
#
	#for id in forest_ids:
		#var new_label = Label.new()
		#new_label.text = str(id)
		#new_label.name = str(id)
		#%LabelBoxForest.add_child(new_label, true)
