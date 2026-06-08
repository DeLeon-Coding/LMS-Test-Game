extends Node3D

@onready var main_camera: Camera3D = $Camera3D
@onready var back_button: Button = $CanvasLayer/BackButton
var current_target: Area3D = null
var default_transform: Transform3D
var selected_item: Node3D = null

func _ready() -> void:
	# Save the starting camera position
	default_transform = main_camera.global_transform
	if back_button:
		back_button.hide()
		# Only connect if not already connected (prevents error if connected in editor)
		if not back_button.pressed.is_connected(_on_back_button_pressed):
			back_button.pressed.connect(_on_back_button_pressed)
	
	# Connect Selectable items (objects you pick up)
	for item in get_tree().get_nodes_in_group("Selectable"):
		if item is CollisionObject3D:
			# Use is_connected check to avoid duplicate connection errors
			var callable = _on_item_clicked.bind(item)
			if not item.input_event.is_connected(callable):
				item.input_event.connect(callable)
	
	# Automatically connect all interactive areas (Clickable and Placement)
	# This ensures "Cooking area" and other placement spots are detected
	var interactive_areas = get_tree().get_nodes_in_group("Clickable")
	for node in get_tree().get_nodes_in_group("Placement"):
		if not interactive_areas.has(node):
			interactive_areas.append(node)
			
	for area in interactive_areas:
		if area is Area3D:
			# Connect click signals
			var click_callable = _on_area_clicked.bind(area)
			if not area.input_event.is_connected(click_callable):
				area.input_event.connect(click_callable)
				
			# Connect hover signals
			var enter_callable = _on_mouse_entered.bind(area)
			if not area.mouse_entered.is_connected(enter_callable):
				area.mouse_entered.connect(enter_callable)
				
			var exit_callable = _on_mouse_exited.bind(area)
			if not area.mouse_exited.is_connected(exit_callable):
				area.mouse_exited.connect(exit_callable)
				
			# Setup brightener material and hide highlight by default
			var mesh = _find_highlight_mesh(area)
			if mesh:
				_setup_highlight_material(mesh)
				mesh.hide()
		else:
			print("Warning: Node '", area.name, "' is in an interactive group but is not an Area3D.")

func _on_mouse_entered(area: Area3D) -> void:
	# Don't highlight if we are already at this target
	if area == current_target:
		return
		
	# Isolate Cooking Area: Only highlight if zoomed into the TableArea
	if area.name == "Cooking area" and (current_target == null or current_target.name != "TableArea"):
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

func _find_highlight_mesh(area: Area3D) -> Node3D:
	for child in area.get_children():
		if child.name.to_lower() == "highlightmesh":
			return child as Node3D
	return null

func _setup_highlight_material(highlight_node: Node3D) -> void:
	# If this piece is a mesh, give it the transparent brightening material
	if highlight_node is MeshInstance3D:
		var mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(1.0, 1.0, 1.0, 0.4) # 40% opacity white for bright glow
		highlight_node.material_override = mat
		
	# Do the same for all children (handles grouped models like the stove)
	for child in highlight_node.get_children():
		_setup_highlight_material(child)

func _on_item_clicked(_camera: Node, event: InputEvent, _pos: Vector3, _norm: Vector3, _idx: int, item: Node3D) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_item = item
		print("Selected: ", item.name)

func _on_back_button_pressed() -> void:
	current_target = null
	move_camera(default_transform)
	if back_button:
		back_button.hide()

func _on_area_clicked(_camera: Node, event: InputEvent, _click_position: Vector3, _click_normal: Vector3, _shape_idx: int, area: Area3D) -> void:
	# Check for left mouse click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		
		# Isolate Cooking Area: Only allow clicking if zoomed into the TableArea
		if area.name == "Cooking area" and (current_target == null or current_target.name != "TableArea"):
			return
			
		# IF WE HAVE AN ITEM SELECTED, PLACE IT INSTEAD OF ZOOMING
		# We check if the area is in the "Placement" group to restrict movement
		if selected_item != null and area.is_in_group("Placement"):
			print("Placing ", selected_item.name, " at ", area.name)
			move_item_to_area(selected_item, area)
			selected_item = null
			return # Stop here so we don't also zoom in
		
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

func move_item_to_area(item: Node3D, area: Area3D) -> void:
	var target_pos = area.global_position
	
	# If the area has a specific PlacementPoint, use that instead
	if area.has_node("PlacementPoint"):
		target_pos = area.get_node("PlacementPoint").global_position
	
	var tween = create_tween()
	tween.tween_property(item, "global_position", target_pos, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Trigger cooking process if placed on a cooking area
	tween.finished.connect(_on_item_placed.bind(item, area))

func _on_item_placed(item: Node3D, area: Area3D) -> void:
	# Check if the area is meant for cooking
	if area.name.to_lower().contains("cooking") or area.name.to_lower().contains("pan"):
		start_cooking(item)

func start_cooking(item: Node3D) -> void:
	print("Cooking started for: ", item.name)
	
	# 1. Simulate cooking time (3 seconds)
	await get_tree().create_timer(3.0).timeout
	
	# 2. Change shape/appearance
	# We use a squash and stretch animation to simulate the "transformation"
	var transform_tween = create_tween()
	transform_tween.set_parallel(false)
	# Squash down
	transform_tween.tween_property(item, "scale", Vector3(1.4, 0.2, 1.4), 0.2).set_trans(Tween.TRANS_CUBIC)
	# Pop back up slightly larger (cooked)
	transform_tween.tween_property(item, "scale", Vector3(1.1, 1.1, 1.1), 0.4).set_trans(Tween.TRANS_ELASTIC)
	
	await transform_tween.finished
	print("Cooking finished!")
	
	# Reset scale to normal if needed, or keep the 'cooked' scale
	# item.scale = Vector3(1.0, 1.0, 1.0)
