extends HBoxContainer


var buttons: Dictionary[int, Button] = {}


func _ready() -> void:
	var grid_size = DataPersistence.grid_size
	var available_sizes = PuzzleProvider.get_available_sizes()
	for child in get_children():
		if child is not Button:
			continue
		var btn: Button = child
		var x_idx := btn.name.find("x")
		var grid_size_str := btn.name.substr(x_idx+1)
		var btn_grid_size := grid_size_str.to_int()
		btn.toggled.connect(_grid_btn_listener(btn_grid_size))
		buttons[btn_grid_size] = btn

		btn.button_pressed = btn_grid_size == grid_size
		btn.disabled = btn_grid_size not in available_sizes

	PuzzleProvider.puzzle_generated.connect(_on_puzzle_generated)


func _set_grid_size(grid_size: int):
	DataPersistence.grid_size = grid_size
	DataPersistence.save()


func _grid_btn_listener(grid_size: int):
	return func(toggled_on: bool):
		_on_grid_btn_toggled(grid_size, toggled_on)


func _on_grid_btn_toggled(grid_size: int, toggled_on: bool):
	if not toggled_on:
		return
	_set_grid_size(grid_size)


func _on_puzzle_generated(available_sizes: Array[int]):
	for button_grid_size in buttons:
		buttons[button_grid_size].disabled = button_grid_size not in available_sizes
