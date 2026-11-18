extends Node


@onready var _persistence: Persistence = $Persistence

var grid_size: int:
	get:
		return _persistence.data.get_or_add("grid_size", 6)
	set(value):
		_persistence.data["grid_size"] = value
var vibrate: bool:
	get:
		return _persistence.data.get_or_add("vibrate", true)
	set(value):
		_persistence.data["vibrate"] = value
var current_theme: String:
	get:
		return _persistence.data.get_or_add("theme", "Purple (Dark)")
	set(value):
		_persistence.data["theme"] = value
var colorblind: bool:
	get:
		return _persistence.data.get_or_add("colorblind", false)
	set(value):
		_persistence.data["colorblind"] = value


const PUZZLE_FMT := "puzzles_%d"
const SCORE_FMT := "score_%d"

var latest_score: Score = null


func save():
	_persistence.save()


func serialize_puzzle(puzzle: Puzzle) -> String:
	var serialized_puzzle := "v1:%d\n" % puzzle.grid_size()
	for cell in puzzle.cells:
		serialized_puzzle += "%s,%s:%d:%d:%d\n" % [
			cell.position.x,
			cell.position.y,
			cell.type,
			1 if cell.invalid else 0,
			cell.region,
		]
	return serialized_puzzle


func deserialize_puzzle(data: String) -> Puzzle:
	if data.begins_with("v1:"):
		return deserialize_puzzle_v1(data)
	return null


func deserialize_puzzle_v1(data: String) -> Puzzle:
	# v1:grid_size
	# x,y:type:invalid:region
	var data_split := data.split("\n")
	var puzzle_header := data_split[0].split(":")
	var puzzle_version = puzzle_header[0]
	if puzzle_version != "v1":
		return null

	var puzzle_grid_size := int(puzzle_header[1])
	var puzzle := Puzzle.new(puzzle_grid_size)
	for cell_data in data_split.slice(1):
		if cell_data.is_empty():
			continue
		var cell_split := cell_data.split(":")

		var grid_position_str := cell_split[0]
		var grid_pos_split := grid_position_str.split(",")
		var grid_position := Vector2(int(grid_pos_split[0]), int(grid_pos_split[1]))

		var cell_type := int(cell_split[1]) as Cell.Type
		var cell_invalid := int(cell_split[2]) != 0
		var cell_region := int(cell_split[3])

		var cell := puzzle.get_cell(grid_position)
		cell.type = cell_type
		cell.invalid = cell_invalid
		cell.region = cell_region
	return puzzle


func store_puzzle(puzzle: Puzzle):
	var puzzle_key := PUZZLE_FMT % puzzle.grid_size()
	var puzzle_data := serialize_puzzle(puzzle)
	var stored_puzzles: Array = _persistence.data.get_or_add(puzzle_key, [])
	stored_puzzles.append(puzzle_data)
	_persistence.data[puzzle_key] = stored_puzzles


func remove_first_puzzle(puzzle_grid_size: int):
	var puzzle_key := PUZZLE_FMT % puzzle_grid_size
	var stored_puzzles: Array = _persistence.data.get_or_add(puzzle_key, [])
	stored_puzzles.pop_front()
	_persistence.data[puzzle_key] = stored_puzzles


func fetch_puzzles(puzzle_grid_size: int) -> Array[Puzzle]:
	var puzzle_key := PUZZLE_FMT % puzzle_grid_size
	var stored_puzzle_data: Array = _persistence.data.get_or_add(puzzle_key, [])
	var puzzles: Array[Puzzle] = []

	for puzzle_data in stored_puzzle_data:
		puzzles.append(deserialize_puzzle(puzzle_data))

	return puzzles


func serialize_score(score: Score) -> String:
	var serialized_score := "v1:%d\t%d" % [score.time_ms, score.timestamp]
	return serialized_score


func deserialize_score(data: String) -> Score:
	var score := deserialize_score_v1(data)
	return score


func deserialize_score_v1(data: String) -> Score:
	# v1:123	123
	var data_split := data.split(":")
	var score_version = data_split[0]
	if score_version != "v1":
		return null

	var score_data := data_split[1]
	var score_data_split := score_data.split("\t")
	var score_time_ms := int(score_data_split[0])
	var score_timestamp := int(score_data_split[1])
	return Score.new(score_time_ms, score_timestamp)


func store_score(score: Score, puzzle_grid_size: int):
	var score_data := serialize_score(score)
	var score_key := SCORE_FMT % puzzle_grid_size
	var stored_scores: Array = _persistence.data.get_or_add(score_key, [])

	# Insert s.t. faster times are at the front of the score array
	var insert_idx := 0
	for i in stored_scores.size():
		var stored_score_data: String = stored_scores[i]
		var stored_score := deserialize_score(stored_score_data)
		if score.time_ms > stored_score.time_ms:
			insert_idx += 1
		else:
			break

	stored_scores.insert(insert_idx, score_data)
	_persistence.data[score_key] = stored_scores
	latest_score = score


func fetch_scores(puzzle_grid_size: int) -> Array[Score]:
	var score_key := SCORE_FMT % puzzle_grid_size
	var stored_scores: Array = _persistence.data.get_or_add(score_key, [])
	var scores: Array[Score] = []

	for score_data in stored_scores:
		scores.append(deserialize_score(score_data))

	return scores
