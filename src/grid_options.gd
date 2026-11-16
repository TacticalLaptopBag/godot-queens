extends HBoxContainer


@onready var buttons: Dictionary[int, Button] = {
	5: $"5x5",
	6: $"6x6",
	7: $"7x7",
}


func _ready() -> void:
	PuzzleProvider.puzzle_generated.connect(_on_puzzle_generated)
	buttons[5].toggled.connect(_on_x4_toggled)
	buttons[6].toggled.connect(_on_x6_toggled)
	buttons[7].toggled.connect(_on_x8_toggled)
	var grid_size = DataPersistence.grid_size
	var available_sizes = PuzzleProvider.get_available_sizes()
	for button_grid_size in buttons:
		var button := buttons[button_grid_size]
		button.button_pressed = button_grid_size == grid_size
		button.disabled = button_grid_size not in available_sizes


func _set_grid_size(grid_size: int):
	DataPersistence.grid_size = grid_size
	DataPersistence.save()


func _on_x4_toggled(toggled_on: bool):
	if not toggled_on: return
	_set_grid_size(5)


func _on_x6_toggled(toggled_on: bool):
	if not toggled_on: return
	_set_grid_size(6)


func _on_x8_toggled(toggled_on: bool):
	if not toggled_on: return
	_set_grid_size(7)


func _on_puzzle_generated(available_sizes: Array[int]):
	for button_grid_size in buttons:
		buttons[button_grid_size].disabled = button_grid_size not in available_sizes
