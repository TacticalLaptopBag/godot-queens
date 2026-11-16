class_name PuzzleGenerator
extends Resource

@export var debug := false
@export var pool_size := 10
@export var grid_size := 6

var _data_persistence: Node = null

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
	_data_persistence = Engine.get_singleton("DataPersistence")
	if _data_persistence:
		_puzzles = _data_persistence.fetch_puzzles(grid_size)
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
	if _data_persistence == null:
		_data_persistence = Engine.get_singleton("DataPersistence")
	if _data_persistence:
		_data_persistence.remove_first_puzzle(puzzle.grid_size())
		_data_persistence.save()

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
	if _data_persistence == null:
		_data_persistence = Engine.get_singleton("DataPersistence")
	var puzzle := _generate_puzzle(grid_size)
	if puzzle == null:
		_in_flight_lock.lock()
		_in_flight -= 1
		_in_flight_lock.unlock()
		puzzle_generated_sem.post()
		return

	_puzzles_lock.lock()
	_puzzles.push_back(puzzle)
	if _data_persistence:
		_data_persistence.store_puzzle(puzzle)
	_puzzles_lock.unlock()

	_in_flight_lock.lock()
	_in_flight -= 1
	_in_flight_lock.unlock()

	if _data_persistence:
		_data_persistence.save()
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


func _generate_regions_first(size: int, rng: RandomNumberGenerator) -> Array:
	# Create region map initialized to -1 (unassigned)
	var region_map: Array = []
	# Type annotation workaround for Godot 4.7
	region_map = []
	for y in range(size):
		var row: Array[int] = []
		for x in range(size):
			row.append(-1)
		region_map.append(row)
	
	# Step 1: Place seeds - one per region, ensure no adjacency
	var seeds: Array[Vector2i] = []
	var attempts := 0
	var max_seed_attempts := 10000
	
	# Create list of all positions and shuffle
	var all_positions: Array[Vector2i] = []
	for y in range(size):
		for x in range(size):
			all_positions.append(Vector2i(x, y))
	
	# Shuffle positions
	for i in range(all_positions.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := all_positions[i]
		all_positions[i] = all_positions[j]
		all_positions[j] = temp
	
	# Pick first size positions that are not adjacent
	for pos in all_positions:
		if seeds.size() >= size:
			break
		
		# Check adjacency to existing seeds (only orthogonal for more flexibility)
		var adjacent := false
		for seed in seeds:
			if abs(seed.x - pos.x) + abs(seed.y - pos.y) == 1:
				adjacent = true
				break
		
		if not adjacent:
			seeds.append(pos)
			region_map[pos.y][pos.x] = seeds.size() - 1
	
	if seeds.size() < size:
		return []
	
	# Step 2: Grow regions randomly
	var frontier: Array[Dictionary] = []
	for i in range(seeds.size()):
		var seed := seeds[i]
		frontier.append({"pos": seed, "reg_id": i})
	
	var unassigned_count := size * size - seeds.size()
	var iterations := 0
	var max_iterations := size * size * 10
	
	while unassigned_count > 0 and iterations < max_iterations:
		iterations += 1
		if frontier.is_empty():
			# No frontier, try to find unassigned cells adjacent to assigned ones
			for y in range(size):
				for x in range(size):
					if region_map[y][x] == -1:
						var adjacent_regions: Array[int] = []
						if y > 0 and region_map[y-1][x] != -1:
							adjacent_regions.append(region_map[y-1][x])
						if y < size - 1 and region_map[y+1][x] != -1:
							adjacent_regions.append(region_map[y+1][x])
						if x > 0 and region_map[y][x-1] != -1:
							adjacent_regions.append(region_map[y][x-1])
						if x < size - 1 and region_map[y][x+1] != -1:
							adjacent_regions.append(region_map[y][x+1])
						
						if adjacent_regions.size() > 0:
							var reg_id := adjacent_regions[rng.randi_range(0, adjacent_regions.size() - 1)]
							region_map[y][x] = reg_id
							unassigned_count -= 1
							frontier.append({"pos": Vector2i(x, y), "reg_id": reg_id})
			continue
		
		# Shuffle frontier for randomness
		for i in range(frontier.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var temp := frontier[i]
			frontier[i] = frontier[j]
			frontier[j] = temp
		
		var item = frontier.pop_front()
		var pos = Vector2i(item.pos)
		var reg_id = int(item.reg_id)
		
		# Get neighbors
		var neighbors: Array[Vector2i] = []
		if pos.x > 0:
			neighbors.append(Vector2i(pos.x - 1, pos.y))
		if pos.x < size - 1:
			neighbors.append(Vector2i(pos.x + 1, pos.y))
		if pos.y > 0:
			neighbors.append(Vector2i(pos.x, pos.y - 1))
		if pos.y < size - 1:
			neighbors.append(Vector2i(pos.x, pos.y + 1))
		
		# Shuffle neighbors
		for i in range(neighbors.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var temp := neighbors[i]
			neighbors[i] = neighbors[j]
			neighbors[j] = temp
		
		var assigned := false
		for n in neighbors:
			if region_map[n.y][n.x] == -1:
				region_map[n.y][n.x] = reg_id
				unassigned_count -= 1
				frontier.append({"pos": n, "reg_id": reg_id})
				assigned = true
				break
		
		# If no neighbor available, keep item in frontier for later
		if not assigned:
			frontier.append(item)
	
	# Step 3: Validate regions are connected
	if not _validate_regions_connected(size, region_map):
		return []
	
	return region_map


func _validate_regions_connected(size: int, region_map: Array) -> bool:
	# Check each region is orthogonally connected via BFS
	for region_id in range(size):
		# Find first cell with this region
		var start_pos: Vector2i = Vector2i(-1, -1)
		for y in range(size):
			for x in range(size):
				if region_map[y][x] == region_id:
					start_pos = Vector2i(x, y)
					break
			if start_pos.x != -1:
				break
		
		if start_pos.x == -1:
			return false  # Region has no cells
		
		# BFS to find all reachable cells in this region
		var visited: Dictionary = {}
		var queue: Array[Vector2i] = [start_pos]
		visited[str(start_pos.x) + "," + str(start_pos.y)] = true
		var count := 0
		
		while queue.size() > 0:
			var pos := Vector2i(queue.pop_front())
			count += 1
			
			var neighbors: Array[Vector2i] = [
				Vector2i(pos.x + 1, pos.y),
				Vector2i(pos.x - 1, pos.y),
				Vector2i(pos.x, pos.y + 1),
				Vector2i(pos.x, pos.y - 1)
			]
			
			for n in neighbors:
				if n.x >= 0 and n.x < size and n.y >= 0 and n.y < size:
					if region_map[n.y][n.x] == region_id:
						var key := str(n.x) + "," + str(n.y)
						if not visited.has(key):
							visited[key] = true
							queue.append(n)
		
		# Count total cells in region
		var total_count := 0
		for y in range(size):
			for x in range(size):
				if region_map[y][x] == region_id:
					total_count += 1
		
		if count != total_count:
			return false  # Region is disconnected
	
	# Also verify all cells are assigned
	for y in range(size):
		for x in range(size):
			if region_map[y][x] == -1:
				return false
	
	return true


func _find_crown_placement(size: int, region_map: Array, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var cols_used: Array[bool] = []
	for i in range(size):
		cols_used.append(false)
	var regions_used: Array[bool] = []
	for i in range(size):
		regions_used.append(false)
	var current_crowns: Array[Vector2i] = []
	return _place_crown_recursive_with_regions(0, size, current_crowns, cols_used, regions_used, region_map, rng)


func _place_crown_recursive_with_regions(row: int, size: int, current_crowns: Array[Vector2i], cols_used: Array[bool], regions_used: Array[bool], region_map: Array, rng: RandomNumberGenerator) -> Array[Vector2i]:
	if row == size:
		return current_crowns
	
	var available_cols: Array[int] = []
	for col in range(size):
		if not cols_used[col]:
			available_cols.append(col)
	
	# Shuffle available columns for randomness
	for i in range(available_cols.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := available_cols[i]
		available_cols[i] = available_cols[j]
		available_cols[j] = temp
	
	for col in available_cols:
		var pos := Vector2i(col, row)
		var region_id := int(region_map[row][col])
		
		# Check constraints
		var valid := true
		
		# Region not used
		if regions_used[region_id]:
			valid = false
		else:
			# No adjacency with placed crowns (8-direction)
			for crown in current_crowns:
				if abs(crown.x - pos.x) <= 1 and abs(crown.y - pos.y) <= 1:
					valid = false
					break
		
		if valid:
			current_crowns.append(pos)
			cols_used[col] = true
			regions_used[region_id] = true
			
			var result := _place_crown_recursive_with_regions(row + 1, size, current_crowns, cols_used, regions_used, region_map, rng)
			if result != null:
				return result
			
			current_crowns.pop_back()
			cols_used[col] = false
			regions_used[region_id] = false
	
	return []


func _count_solutions(size: int, region_map: Array, limit: int) -> int:
	var cols_used: Array[bool] = []
	for i in range(size):
		cols_used.append(false)
	var regions_used: Array[bool] = []
	for i in range(size):
		regions_used.append(false)
	var current_crowns: Array[Vector2i] = []
	var count_ref: Array[int] = [0]
	_count_solutions_recursive(0, size, current_crowns, cols_used, regions_used, region_map, limit, count_ref)
	return count_ref[0]


func _count_solutions_recursive(row: int, size: int, current_crowns: Array[Vector2i], cols_used: Array[bool], regions_used: Array[bool], region_map: Array, limit: int, count_ref: Array[int]) -> bool:
	if count_ref[0] >= limit:
		return true
	
	if row == size:
		count_ref[0] += 1
		return count_ref[0] >= limit
	
	var available_cols: Array[int] = []
	for col in range(size):
		if not cols_used[col]:
			available_cols.append(col)
	
	# Try columns in order (no shuffle for counting)
	for col in available_cols:
		var pos := Vector2i(col, row)
		var region_id := int(region_map[row][col])
		
		# Check constraints
		var valid := true
		
		if regions_used[region_id]:
			valid = false
		else:
			for crown in current_crowns:
				if abs(crown.x - pos.x) <= 1 and abs(crown.y - pos.y) <= 1:
					valid = false
					break
		
		if valid:
			current_crowns.append(pos)
			cols_used[col] = true
			regions_used[region_id] = true
			
			if _count_solutions_recursive(row + 1, size, current_crowns, cols_used, regions_used, region_map, limit, count_ref):
				current_crowns.pop_back()
				cols_used[col] = false
				regions_used[region_id] = false
				return true
			
			current_crowns.pop_back()
			cols_used[col] = false
			regions_used[region_id] = false
	
	return count_ref[0] >= limit


func _build_puzzle(size: int, region_map: Array, crowns: Array[Vector2i]) -> Puzzle:
	var puzzle := Puzzle.new(size)
	
	for y in range(size):
		for x in range(size):
			var cell := puzzle.get_cell(Vector2i(x, y))
			cell.region = region_map[y][x]
	
	puzzle.solution_crowns = crowns
	return puzzle


func _generate_puzzle(size: int) -> Puzzle:
	print("Generating %dx%d puzzle..." % [size, size])
	var start_ticks := Time.get_ticks_msec()
	
	# Size-dependent attempts for better success rates
	var max_attempts := 100
	match size:
		4:
			max_attempts = 100
		5:
			max_attempts = 500
		6:
			max_attempts = 500
		7, 8:
			max_attempts = 1000
	
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	
	for attempt in range(max_attempts):
		if _should_stop():
			return null
		
		# Generate regions first
		var region_map := _generate_regions_first(size, rng)
		if region_map.is_empty():
			continue
		
		# Find crown placement with backtracking
		var local_rng := RandomNumberGenerator.new()
		local_rng.randomize()
		var crowns := _find_crown_placement(size, region_map, local_rng)
		
		if crowns.is_empty():
			continue
		
		# Check uniqueness by counting solutions
		var solution_count := _count_solutions(size, region_map, 2)
		if solution_count == 1:
			var puzzle := _build_puzzle(size, region_map, crowns)
			
			if debug:
				print("Solution crowns: ", crowns)
				print("Region map:")
				for row in region_map:
					print(row)
			
			var end_ticks := Time.get_ticks_msec()
			print("Generation for %dx%d took %dms (attempt %d)" % [size, size, end_ticks - start_ticks, attempt + 1])
			return puzzle
	
	print("Failed to generate unique puzzle for size %d after %d attempts" % [size, max_attempts])
	return null
