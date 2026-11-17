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
	var puzzle: Puzzle = null
	while puzzle == null:
		_puzzles_lock.lock()
		puzzle = _puzzles.pop_front()
		if puzzle != null:
			# Done under the lock so the in-memory pool and the persisted pool stay in sync.
			DataPersistence.remove_first_puzzle(puzzle.grid_size())
		_puzzles_lock.unlock()

		if puzzle == null:
			if _is_stopped():
				return null
			# Pool is empty: make sure something is being generated, then wait for it.
			_top_up_pool()
			puzzle_generated_sem.wait()

	DataPersistence.save()

	# A puzzle was consumed — schedule a replacement.
	_top_up_pool()
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
		_in_flight_lock.lock()
		_in_flight -= 1
		_in_flight_lock.unlock()
		puzzle_generated_sem.post()
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


## Determines if the generator needs to be cut short, likely due to application close.
## (The in-flight counter is decremented by _generate_and_store when it sees a null puzzle.)
func _should_stop() -> bool:
	return _is_stopped()


func _is_stopped() -> bool:
	_stop_lock.lock()
	var should_stop := _stop
	_stop_lock.unlock()
	return should_stop


# ---------------------------------------------------------------------------
# Puzzle generation
#
# Strategy: build the answer first, then build a board around it.
#   1. Pick a random valid queen placement (one per row/column, none touching).
#   2. Grow one region outward from each queen. Every region now holds exactly
#      one queen of that placement, so the placement is a valid solution.
#   3. Count solutions. If another one exists, move a single cell from one
#      region to a neighbouring region so that the other solution breaks while
#      the intended one survives. Repeat until the solution is unique.
#
# Region maps are flat PackedInt32Arrays indexed by (y * size + x).
# ---------------------------------------------------------------------------

# Upper bound on repair steps for a single board before it is thrown away and
# a fresh one is built. Boards normally converge in a handful of steps.
const MAX_REPAIR_STEPS := 100
# Safety valve only; in practice the first few boards succeed.
const MAX_BOARD_ATTEMPTS := 1000

const _DIRS_4: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]


func _generate_puzzle(size: int) -> Puzzle:
	if size == 2 or size == 3 or size < 1:
		push_error("Queens puzzles cannot exist for grid size %d" % size)
		return null

	var start_ticks := Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for attempt in range(MAX_BOARD_ATTEMPTS):
		if _should_stop():
			return null

		var solution := _generate_solution(size, rng)
		if solution.is_empty():
			continue

		var regions := _grow_regions(size, solution, rng)
		if not _make_unique(size, regions, solution, rng):
			continue

		var puzzle := _build_puzzle(size, regions, solution)
		if debug:
			print("Solution columns by row: ", solution)
			print("Region map:")
			for y in range(size):
				print(regions.slice(y * size, (y + 1) * size))
		print("Generation for %dx%d took %dms (attempt %d)" % [
			size, size, Time.get_ticks_msec() - start_ticks, attempt + 1,
		])
		return puzzle

	push_warning("Failed to generate unique puzzle for size %d after %d attempts" % [size, MAX_BOARD_ATTEMPTS])
	return null


## Returns an Array of columns, one per row (solution[row] = column of that row's queen).
func _generate_solution(size: int, rng: RandomNumberGenerator) -> PackedInt32Array:
	var solution := PackedInt32Array()
	solution.resize(size)
	if _place_queen_row(0, size, 0, -1, solution, rng):
		return solution
	return PackedInt32Array()


func _place_queen_row(row: int, size: int, cols_mask: int, prev_col: int, solution: PackedInt32Array, rng: RandomNumberGenerator) -> bool:
	if row == size:
		return true
	for col in _shuffled_range(size, rng):
		if cols_mask & (1 << col):
			continue
		# Queens in consecutive rows may not touch (diagonally or otherwise).
		if prev_col >= 0 and absi(col - prev_col) <= 1:
			continue
		solution[row] = col
		if _place_queen_row(row + 1, size, cols_mask | (1 << col), col, solution, rng):
			return true
	return false


## Grows one connected region from each queen until every cell is assigned.
func _grow_regions(size: int, solution: PackedInt32Array, rng: RandomNumberGenerator) -> PackedInt32Array:
	var regions := PackedInt32Array()
	regions.resize(size * size)
	regions.fill(-1)

	# Shuffle region ids so a region's id doesn't correlate with its queen's row.
	var ids := _shuffled_range(size, rng)
	for row in range(size):
		regions[row * size + solution[row]] = ids[row]

	var unassigned := size * size - size
	while unassigned > 0:
		# Every (empty cell, adjacent region) pair is a legal growth step.
		var options: Array[Vector2i] = []
		for idx in range(size * size):
			if regions[idx] != -1:
				continue
			var x := idx % size
			var y := idx / size
			for dir in _DIRS_4:
				var nx := x + dir.x
				var ny := y + dir.y
				if nx < 0 or ny < 0 or nx >= size or ny >= size:
					continue
				var neighbor_region := regions[ny * size + nx]
				if neighbor_region != -1:
					options.append(Vector2i(idx, neighbor_region))

		var pick := options[rng.randi_range(0, options.size() - 1)]
		regions[pick.x] = pick.y
		unassigned -= 1

	return regions


## Repeatedly breaks alternative solutions until only `solution` is left.
## Returns false if the board could not be fixed (caller should start over).
func _make_unique(size: int, regions: PackedInt32Array, solution: PackedInt32Array, rng: RandomNumberGenerator) -> bool:
	for _step in range(MAX_REPAIR_STEPS):
		var found := _find_solutions(size, regions, 2)
		if found.is_empty():
			return false # Should be impossible: `solution` is always kept valid.
		if found.size() == 1:
			return true # The only solution is the intended one.

		var other := found[1] if found[0] == solution else found[0]
		if not _break_solution(size, regions, solution, other, rng):
			return false
	return false


## Changes one cell's region so that `other` stops being a valid solution
## while `solution` stays valid. Returns false if no safe change exists.
##
## `other` places a queen on some cell the intended solution doesn't use.
## Re-assigning that cell to a neighbouring region gives `other` two queens in
## one region (and none in the other), so it can no longer be a solution.
func _break_solution(size: int, regions: PackedInt32Array, solution: PackedInt32Array, other: PackedInt32Array, rng: RandomNumberGenerator) -> bool:
	var region_sizes := PackedInt32Array()
	region_sizes.resize(size)
	for region in regions:
		region_sizes[region] += 1

	var preferred: Array[Vector2i] = [] # (cell index, new region) keeping the old region >= 2 cells
	var fallback: Array[Vector2i] = []

	for row in range(size):
		if other[row] == solution[row]:
			continue
		var idx := row * size + other[row] # never one of the intended queens
		var from_region := regions[idx]
		if not _region_connected_without(size, regions, solution, idx):
			continue

		var x := idx % size
		var y := idx / size
		var seen_regions := {}
		for dir in _DIRS_4:
			var nx := x + dir.x
			var ny := y + dir.y
			if nx < 0 or ny < 0 or nx >= size or ny >= size:
				continue
			var to_region := regions[ny * size + nx]
			if to_region == from_region or seen_regions.has(to_region):
				continue
			seen_regions[to_region] = true
			var option := Vector2i(idx, to_region)
			if region_sizes[from_region] > 2:
				preferred.append(option)
			else:
				fallback.append(option)

	var pool := preferred if not preferred.is_empty() else fallback
	if pool.is_empty():
		return false

	var choice := pool[rng.randi_range(0, pool.size() - 1)]
	regions[choice.x] = choice.y
	return true


## True if the region containing `removed_idx` stays orthogonally connected
## once that cell is taken out of it.
func _region_connected_without(size: int, regions: PackedInt32Array, solution: PackedInt32Array, removed_idx: int) -> bool:
	var region := regions[removed_idx]

	var remaining := 0
	for idx in range(size * size):
		if regions[idx] == region and idx != removed_idx:
			remaining += 1
	if remaining == 0:
		return false # Would delete the region entirely.

	# Start the flood fill from this region's intended queen (always present).
	var start := -1
	for row in range(size):
		var queen_idx := row * size + solution[row]
		if regions[queen_idx] == region:
			start = queen_idx
			break
	if start == -1:
		return false

	var visited := PackedByteArray()
	visited.resize(size * size)
	visited[start] = 1
	var stack: Array[int] = [start]
	var reached := 0
	while not stack.is_empty():
		var idx: int = stack.pop_back()
		reached += 1
		var x := idx % size
		var y := idx / size
		for dir in _DIRS_4:
			var nx := x + dir.x
			var ny := y + dir.y
			if nx < 0 or ny < 0 or nx >= size or ny >= size:
				continue
			var n_idx := ny * size + nx
			if n_idx == removed_idx or visited[n_idx] == 1 or regions[n_idx] != region:
				continue
			visited[n_idx] = 1
			stack.append(n_idx)

	return reached == remaining


## Finds up to `limit` distinct solutions. Each solution is an array of
## columns, one per row.
func _find_solutions(size: int, regions: PackedInt32Array, limit: int) -> Array[PackedInt32Array]:
	var found: Array[PackedInt32Array] = []
	var current := PackedInt32Array()
	current.resize(size)
	_search_row(0, size, regions, 0, 0, -1, current, found, limit)
	return found


func _search_row(row: int, size: int, regions: PackedInt32Array, cols_mask: int, regions_mask: int, prev_col: int, current: PackedInt32Array, found: Array[PackedInt32Array], limit: int) -> void:
	if row == size:
		found.append(current.duplicate())
		return

	for col in range(size):
		if cols_mask & (1 << col):
			continue
		if prev_col >= 0 and absi(col - prev_col) <= 1:
			continue
		var region_bit := 1 << regions[row * size + col]
		if regions_mask & region_bit:
			continue

		current[row] = col
		_search_row(row + 1, size, regions, cols_mask | (1 << col), regions_mask | region_bit, col, current, found, limit)
		if found.size() >= limit:
			return


func _shuffled_range(count: int, rng: RandomNumberGenerator) -> Array[int]:
	var values: Array[int] = []
	for i in range(count):
		values.append(i)
	for i in range(count - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := values[i]
		values[i] = values[j]
		values[j] = temp
	return values


func _build_puzzle(size: int, regions: PackedInt32Array, solution: PackedInt32Array) -> Puzzle:
	var puzzle := Puzzle.new(size)

	for y in range(size):
		for x in range(size):
			var cell := puzzle.get_cell(Vector2i(x, y))
			cell.region = regions[y * size + x]

	var crowns: Array[Vector2i] = []
	for row in range(size):
		crowns.append(Vector2i(solution[row], row))
	puzzle.solution_crowns = crowns
	return puzzle
