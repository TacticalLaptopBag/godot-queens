class_name Tile
extends Sprite2D


@export var tap_haptics := HapticConfig.new()
@export var long_press_haptics := HapticConfig.new()
@export var invalid_haptics := HapticConfig.new()

@onready var mark: Sprite2D = $Mark
@onready var crown: Sprite2D = $Crown
@onready var fill_sprite: Sprite2D = $Fill
@onready var invalid_sprite: Sprite2D = $Invalid
@onready var click_detector: Area2D = $ClickDetector
@onready var long_press_timer: Timer = $LongPressTimer
@onready var invalid_timer: Timer = $InvalidTimer
@onready var selection_indicator: Sprite2D = $SelectionIndicator

signal cell_type_changed(cell: Cell, old_type: Cell.Type)


var selected := false:
	set(value):
		selected = value
		_update_selected_appearance()


var cell: Cell = null:
	set(value):
		if cell != null:
			cell.type_changed.disconnect(_on_cell_type_changed)
			cell.invalid_changed.disconnect(_on_cell_invalid_changed)
			cell.locked_changed.disconnect(_on_cell_locked_changed)
		cell = value
		cell.type_changed.connect(_on_cell_type_changed)
		cell.invalid_changed.connect(_on_cell_invalid_changed)
		cell.locked_changed.connect(_on_cell_locked_changed)
		_update_theme(ThemeManager.current_theme)


func _ready() -> void:
	ThemeManager.theme_changed.connect(_update_theme)


func _update_appearance():
	_update_type_appearance()
	_on_cell_locked_changed(cell, cell.locked)
	_update_selected_appearance()
	_update_invalid_appearance()


func _update_selected_appearance():
	selection_indicator.visible = selected


var _drag_started := false

func _on_click_detector_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if cell.locked:
		return

	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
				long_press_timer.start()
				_drag_started = false
		elif event.is_released():
			if event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
				long_press_timer.stop()
				if not _drag_started:
					# No drag occurred, this was a click
					toggle_tile_type()
					tap_haptics.vibrate()
				_drag_started = false
			elif event.button_index == MouseButton.MOUSE_BUTTON_RIGHT:
				toggle_crown_tile()
			elif event.button_index == MouseButton.MOUSE_BUTTON_MIDDLE:
				clear_tile()
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		# Handle drag to mark multiple cells
		if Input.is_mouse_button_pressed(MouseButton.MOUSE_BUTTON_LEFT):
			_drag_started = true
			# Mark cells as we drag over them
			# Stop long press timer to prevent crown toggle
			if not long_press_timer.is_stopped():
				long_press_timer.stop()
			# Only set to MARK if empty, don't toggle to crown
			if cell.type == Cell.Type.EMPTY:
				cell.type = Cell.Type.MARK
				tap_haptics.vibrate()


func _on_long_press_timer_timeout():
	toggle_crown_tile()
	long_press_haptics.vibrate()


func toggle_tile_type():
	if cell.locked:
		return

	var new_type: Cell.Type
	match cell.type:
		Cell.Type.EMPTY:
			new_type = Cell.Type.MARK
		Cell.Type.MARK, Cell.Type.AUTO_MARK:
			new_type = Cell.Type.CROWN
		_:
			new_type = Cell.Type.EMPTY
	cell.type = new_type


func toggle_crown_tile():
	if cell.locked:
		return

	var new_type := Cell.Type.EMPTY if cell.type == Cell.Type.CROWN else Cell.Type.CROWN
	cell.type = new_type


func clear_tile():
	if cell.locked:
		return

	cell.type = Cell.Type.EMPTY


func _update_color():
	var region_color := ThemeManager.current_theme.regions[cell.region]
	mark.modulate = region_color.fg_color
	crown.modulate = region_color.fg_color
	fill_sprite.modulate = region_color.bg_color
	selection_indicator.modulate = ThemeManager.current_theme.selection
	self_modulate = ThemeManager.current_theme.normal


func _update_type_appearance():
	mark.visible = cell.type == Cell.Type.MARK or cell.type == Cell.Type.AUTO_MARK
	crown.visible = cell.type == Cell.Type.CROWN


func _update_invalid_appearance():
	invalid_sprite.visible = cell.invalid
	_update_color()
	if cell.invalid:
		invalid_haptics.vibrate()


func _on_cell_type_changed(_cell: Cell, old_type: Cell.Type):
	# print("Cell at "+str(cell.position)+" changed type to "+str(cell.type))
	_update_type_appearance()
	cell_type_changed.emit(cell, old_type)


func _on_cell_invalid_changed(_cell: Cell, _old_invalid: bool):
	# print("Cell at "+str(cell.position)+" changed invalid to "+str(cell.invalid))
	if cell.invalid:
		invalid_timer.start()
	else:
		invalid_timer.stop()
		_update_invalid_appearance()


func _on_cell_locked_changed(_cell: Cell, _old_locked: bool):
	# print("Cell at "+str(cell.position)+" changed locked to "+str(cell.locked))
	click_detector.monitorable = not cell.locked
	click_detector.monitoring = not cell.locked
	_update_color()


func update_transform(grid_size: int, tile_padding: int, grid_padding: Vector2):
	var viewport_size := get_viewport().get_visible_rect().size - (grid_padding * 2)
	var cell_size: float = min(viewport_size.x / grid_size, viewport_size.y / grid_size)
	var texture_size := Vector2(texture.get_width(), texture.get_height())

	var scale_factor := Vector2(cell_size, cell_size) / texture_size
	var tile_size := texture_size * scale_factor
	var tile_position := (cell.position - Vector2(grid_size / 2.0, grid_size / 2.0)) * (tile_size + Vector2(tile_padding, tile_padding))
	tile_position += tile_size / 2.0

	position = tile_position
	scale = scale_factor


func _on_invalid_timer_timeout() -> void:
	_update_invalid_appearance()


func _update_theme(theme: GameTheme):
	if not is_node_ready(): return
	if theme == null: return
	_update_appearance()
