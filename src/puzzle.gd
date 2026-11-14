class_name Puzzle
extends Resource


@export var cells: Array[Cell] = []
@export var solution_crowns: Array[Vector2i] = []
var _size: int = -1
var auto_marks_enabled: bool = true


func _init(size: int = 6):
	_populate(size)


func get_cell(grid_position: Vector2i) -> Cell:
	return Util.get_item_from_2d(grid_position, cells, _size, _size)


func _populate(size: int):
	for y in range(size):
		for x in range(size):
			var cell := Cell.new(Vector2(x, y))
			cells.append(cell)
	_size = floor(sqrt(cells.size()))

	for cell in cells:
		cell.north = get_cell(cell.position - Vector2(0, 1))
		cell.south = get_cell(cell.position + Vector2(0, 1))
		cell.west = get_cell(cell.position - Vector2(1, 0))
		cell.east = get_cell(cell.position + Vector2(1, 0))


func grid_size() -> int:
	return _size


func is_filled() -> bool:
	for cell in cells:
		if cell.type == Cell.Type.EMPTY:
			return false
	return true


func has_all_crowns_placed() -> bool:
	var crown_count := 0
	for cell in cells:
		if cell.type == Cell.Type.CROWN:
			crown_count += 1
	return crown_count == _size


func update_auto_marks():
	if not auto_marks_enabled:
		return

	# Clear all AUTO_MARK to EMPTY
	for cell in cells:
		if cell.type == Cell.Type.AUTO_MARK:
			cell.type = Cell.Type.EMPTY

	# Apply auto-marks for each crown
	for cell in cells:
		if cell.type == Cell.Type.CROWN:
			# Mark same row
			for x in range(_size):
				var row_cell = get_cell(Vector2i(x, int(cell.position.y)))
				if row_cell != cell and row_cell.type == Cell.Type.EMPTY:
					row_cell.type = Cell.Type.AUTO_MARK

			# Mark same column
			for y in range(_size):
				var col_cell = get_cell(Vector2i(int(cell.position.x), y))
				if col_cell != cell and col_cell.type == Cell.Type.EMPTY:
					col_cell.type = Cell.Type.AUTO_MARK

			# Mark 8 neighbors
			for direction in Cell.Direction.values():
				var neighbor = cell.get_neighbor(direction)
				if neighbor != null and neighbor != cell and neighbor.type == Cell.Type.EMPTY:
					neighbor.type = Cell.Type.AUTO_MARK


func _find_crowns_per_row() -> Array[Cell]:
	var problem_cells: Array[Cell] = []
	for y in range(_size):
		var crowns_in_row: Array[Cell] = []
		for x in range(_size):
			var cell = get_cell(Vector2i(x, y))
			if cell.type == Cell.Type.CROWN:
				crowns_in_row.append(cell)
		if crowns_in_row.size() > 1:
			problem_cells.append_array(crowns_in_row)
	return problem_cells


func _find_crowns_per_column() -> Array[Cell]:
	var problem_cells: Array[Cell] = []
	for x in range(_size):
		var crowns_in_column: Array[Cell] = []
		for y in range(_size):
			var cell = get_cell(Vector2i(x, y))
			if cell.type == Cell.Type.CROWN:
				crowns_in_column.append(cell)
		if crowns_in_column.size() > 1:
			problem_cells.append_array(crowns_in_column)
	return problem_cells


func _find_crowns_per_region() -> Array[Cell]:
	var problem_cells: Array[Cell] = []
	var regions := {}
	for cell in cells:
		if cell.type == Cell.Type.CROWN:
			if not regions.has(cell.region):
				regions[cell.region] = []
			regions[cell.region].append(cell)

	for region_id in regions.keys():
		var crowns_in_region = regions[region_id]
		if crowns_in_region.size() > 1:
			problem_cells.append_array(crowns_in_region)
	return problem_cells


func _find_touching_crowns() -> Array[Cell]:
	var problem_cells: Array[Cell] = []
	for cell in cells:
		if cell.type == Cell.Type.CROWN:
			var adjacent_crowns = cell.get_adjacent_crowns()
			for neighbor in adjacent_crowns:
				if neighbor.type == Cell.Type.CROWN:
					if not problem_cells.has(cell):
						problem_cells.append(cell)
					if not problem_cells.has(neighbor):
						problem_cells.append(neighbor)
	return problem_cells


func get_problem_cells() -> Array[Cell]:
	var problem_cells: Array[Cell] = []
	problem_cells.append_array(_find_crowns_per_row())
	problem_cells.append_array(_find_crowns_per_column())
	problem_cells.append_array(_find_crowns_per_region())
	problem_cells.append_array(_find_touching_crowns())

	# Remove duplicates
	var unique_cells: Array[Cell] = []
	for cell in problem_cells:
		if not unique_cells.has(cell):
			unique_cells.append(cell)
	return unique_cells


func validate() -> bool:
	update_auto_marks()
	var problem_cells := get_problem_cells()
	for cell in cells:
		cell.invalid = cell in problem_cells

	return problem_cells.is_empty()
