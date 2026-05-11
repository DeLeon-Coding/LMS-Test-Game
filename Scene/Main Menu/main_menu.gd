extends Node2D


func _on_quit_pressed() -> void:
	print("Quit button pressed")
	get_tree().quit()


func _on_option_pressed() -> void:
	print("Option button pressed")
	get_tree().change_scene_to_file("")

func _on_start_pressed() -> void:
	print("Start button pressed")
	get_tree().change_scene_to_file("res://Scene/Module/Module_1_test.tscn")
