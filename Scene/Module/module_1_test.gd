extends Node3D

@onready var main_camera: Camera3D = $Camera3D
@onready var back_button: Button = $CanvasLayer/BackButton
var current_target: Area3D = null
var default_transform: Transform3D

func _ready() -> void:
	# Save the starting camera position
	default_transform = main_camera.global_transform
	if back_button:
		back_button.hide()
		back_button.pressed.connect(_on_back_button_pressed)
	
	# Automatically connect all nodes in the "Clickable" group
	# This avoids having to hardcode names like "TableArea"
	for area in get_tree().get_nodes_in_group("Clickable"):
		if area is Area3D:
			area.input_event.connect(_on_area_clicked.bind(area))
			# Connect hover signals
			area.mouse_entered.connect(_on_mouse_entered.bind(area))
			area.mouse_exited.connect(_on_mouse_exited.bind(area))
			# Hide highlight by default
			var mesh = _find_highlight_mesh(area)
			if mesh:
				mesh.hide()
		else:
			print("Warning: Node '", area.name, "' is in 'Clickable' group but is not an Area3D.")

func _on_mouse_entered(area: Area3D) -> void:
	# Don't highlight if we are already at this target
	if area == current_target:
		return
		
	print("Mouse entered: ", area.name)
	var mesh = _find_highlight_mesh(area)
	if mesh:
		mesh.show()

func _on_mouse_exited(area: Area3D) -> void:
	print("Mouse exited: ", area.name)
	var mesh = _find_highlight_mesh(area)
	if mesh:
		mesh.hide()

func _find_highlight_mesh(area: Area3D) -> MeshInstance3D:
	for child in area.get_children():
		if child.name.to_lower() == "highlightmesh":
			return child as MeshInstance3D
	return null

func _on_back_button_pressed() -> void:
	current_target = null
	move_camera(default_transform)
	if back_button:
		back_button.hide()

func _on_area_clicked(_camera: Node, event: InputEvent, _click_position: Vector3, _click_normal: Vector3, _shape_idx: int, area: Area3D) -> void:
	# Check for left mouse click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Moving to: ", area.name)
		current_target = area
		
		# Show the back button when we zoom in
		if back_button:
			back_button.show()
		
		# Hide the highlight immediately when clicked
		var mesh = _find_highlight_mesh(area)
		if mesh:
			mesh.hide()
		
		# Ensure the area has a Marker3D child
		if area.has_node("Marker3D"):
			var target_marker = area.get_node("Marker3D")
			move_camera(target_marker.global_transform)
		else:
			print("Warning: ", area.name, " is missing a Marker3D child.")

func move_camera(target_transform: Transform3D) -> void:
	var tween = create_tween()
	# Move and Rotate simultaneously
	tween.set_parallel(true)
	tween.tween_property(main_camera, "global_transform", target_transform, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
