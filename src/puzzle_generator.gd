class_name PuzzleGenerator
extends Resource

@export var debug := false
@export var pool_size := 10
@export var grid_size := 6

var _puzzles: Array[Puzzle] = []
var _puzzles_lock := Mutex.new()
var puzzle_generated_sem := Semaphore.new()

# Tracks how many puzzles are currently being generated, so we don't
# over-schedule when multiple get_puzzle() calls come in at once.
var _in_flight := 0
var _in_flight_lock := Mutex.new()
var _task_ids: Array[int] = []

var _stop := false
var _stop_lock := Mutex.new()

signal puzzle_generated(generator: PuzzleGenerator)


func queue_generation():
	_puzzles = DataPersistence.fetch_puzzles(grid_size)
	_top_up_pool()


func is_puzzle_ready() -> bool:
	_puzzles_lock.lock()
	var size := _puzzles.size()
	_puzzles_lock.unlock()
	return size > 0


func get_puzzle() -> Puzzle:
	_puzzles_lock.lock()
	var puzzle: Puzzle = _puzzles.pop_front()
	_puzzles_lock.unlock()
	DataPersistence.remove_first_puzzle(puzzle.grid_size())
	DataPersistence.save()

	# A puzzle was consumed — schedule a replacement.
	_top_up_pool()

	if puzzle == null:
		puzzle_generated_sem.wait()
		return get_puzzle()

	return puzzle


# No thread ownership to clean up — WorkerThreadPool manages its own
# threads. Call this if you need to wait for all in-flight tasks before
# quitting, e.g. in _notification(NOTIFICATION_WM_CLOSE_REQUEST).
func wait_for_cleanup_finish():
	_stop_lock.lock()
	_stop = true
	_stop_lock.unlock()
	for task_id in _task_ids:
		WorkerThreadPool.wait_for_task_completion(task_id)


func _top_up_pool():
	_puzzles_lock.lock()
	var puzzles_ready := _puzzles.size()
	_puzzles_lock.unlock()

	_in_flight_lock.lock()
	var in_flight := _in_flight
	_in_flight_lock.unlock()

	var needed := pool_size - puzzles_ready - in_flight
	for _i in range(needed):
		_in_flight_lock.lock()
		_in_flight += 1
		_in_flight_lock.unlock()
		var task_id := WorkerThreadPool.add_task(_generate_and_store)
		_task_ids.append(task_id)


func _generate_and_store():
	var puzzle := _generate_puzzle(grid_size)
	if puzzle == null:
		return

	_puzzles_lock.lock()
	_puzzles.push_back(puzzle)
	DataPersistence.store_puzzle(puzzle)
	_puzzles_lock.unlock()

	_in_flight_lock.lock()
	_in_flight -= 1
	_in_flight_lock.unlock()

	DataPersistence.save()
	puzzle_generated_sem.post()
	puzzle_generated.emit.call_deferred(self)


## Determines if the generator needs to be cut short, likely due to application close
func _should_stop() -> bool:
	_stop_lock.lock()
	var should_stop := _stop
	_stop_lock.unlock()
	if should_stop:
		_in_flight_lock.lock()
		_in_flight -= 1
		_in_flight_lock.unlock()
	return should_stop


func _solve_crown_placement(size: int) -> Array[Vector2i]:
	var cols_used: Array[bool] = []
	for i in range(size):
		cols_used.append(false)
	var current_crowns: Array[Vector2i] = []
	return _place_crown_recursive(0, size, current_crowns, cols_used)


func _place_crown_recursive(row: int, size: int, current_crowns: Array[Vector2i], cols_used: Array[bool]) -> Array[Vector2i]:
	if row == size:
		return current_crowns
	
	for col in range(size):
		if cols_used[col]:
			continue
		
		var pos := Vector2i(col, row)
		var valid := true
		for crown in current_crowns:
			if abs(crown.x - pos.x) <= 1 and abs(crown.y - pos.y) <= 1:
				valid = false
				break
		
		if valid:
			current_crowns.append(pos)
			cols_used[col] = true
			
			var result := _place_crown_recursive(row + 1, size, current_crowns, cols_used)
			if result != null:
				return result
			
			current_crowns.pop_back()
			cols_used[col] = false
	
	return []


func _generate_regions(size: int, crowns: Array[Vector2i]) -> Array:
	var region_map: Array = []
	for y in range(size):
		var row: Array[int] = []
		for x in range(size):
			row.append(-1)
		region_map.append(row)
	
	var queue: Array[Dictionary] = []
	for i in range(crowns.size()):
		var crown := crowns[i]
		region_map[crown.y][crown.x] = i
		queue.append({"pos": crown, "reg_id": i})
	
	while queue.size() > 0:
		var item = queue.pop_front()
		var pos: Vector2i = item.pos
		var reg_id: int = item.reg_id
		
		var neighbors := [
			Vector2i(pos.x + 1, pos.y),
			Vector2i(pos.x - 1, pos.y),
			Vector2i(pos.x, pos.y + 1),
			Vector2i(pos.x, pos.y - 1)
		]
		
		for n in neighbors:
			if n.x >= 0 and n.x < size and n.y >= 0 and n.y < size:
				if region_map[n.y][n.x] == -1:
					region_map[n.y][n.x] = reg_id
					queue.append({"pos": n, "reg_id": reg_id})
	
	return region_map


func _generate_puzzle(size: int) -> Puzzle:
	print("Generating %dx%d puzzle..." % [size, size])
	var puzzle := Puzzle.new(size)

	var start_ticks := Time.get_ticks_msec()

	var crowns := _solve_crown_placement(size)
	if crowns.is_empty():
		print("Failed to place crowns for size %d" % size)
		return null

	var region_map := _generate_regions(size, crowns)
	
	for y in range(size):
		for x in range(size):
			var cell := puzzle.get_cell(Vector2i(x, y))
			cell.region = region_map[y][x]
	
	puzzle.solution_crowns = crowns

	if debug:
		print("Solution crowns: ", crowns)
		print("Region map:")
		for row in region_map:
			print(row)

	var end_ticks := Time.get_ticks_msec()
	print("Generation for %dx%d took %dms" % [size, size, end_ticks - start_ticks])

	return puzzle
