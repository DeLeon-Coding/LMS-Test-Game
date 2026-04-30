extends Node2D


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_option_pressed() -> void:
	get_tree().change_scene_to_file("")

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://Scene/Main Menu/main_menu.tscn")
