class_name Cell
extends Resource


var type := Type.EMPTY:
	set(value):
		if type != value:
			var old_type := type
			type = value
			type_changed.emit(self, old_type)
var position := Vector2.ZERO

var locked := false:
	set(value):
		if locked != value:
			var old_locked := locked
			locked = value
			locked_changed.emit(self, old_locked)
var invalid := false:
	set(value):
		if invalid != value:
			var old_invalid := invalid
			invalid = value
			invalid_changed.emit(self, old_invalid)
var region := 0:
	set(value):
		if region != value:
			var old_region := region
			region = value
			region_changed.emit(self, old_region)

var north: Cell = null
var south: Cell = null
var east: Cell = null
var west: Cell = null


signal type_changed(cell: Cell, old_type: Type)
signal invalid_changed(cell: Cell, old_invalid: bool)
signal locked_changed(cell: Cell, old_locked: bool)
signal region_changed(cell: Cell, old_region: int)


func _init(grid_position: Vector2):
	position = grid_position


enum Type {
	EMPTY,
	MARK,
	AUTO_MARK,
	CROWN,
}


enum Direction {
	NORTH,
	NORTHEAST,
	EAST,
	SOUTHEAST,
	SOUTH,
	SOUTHWEST,
	WEST,
	NORTHWEST,
}


static func invert_direction(direction: Direction) -> Direction:
	match direction:
		Direction.NORTH:
			return Direction.SOUTH
		Direction.NORTHEAST:
			return Direction.SOUTHWEST
		Direction.EAST:
			return Direction.WEST
		Direction.SOUTHEAST:
			return Direction.NORTHWEST
		Direction.SOUTH:
			return Direction.NORTH
		Direction.SOUTHWEST:
			return Direction.NORTHEAST
		Direction.WEST:
			return Direction.EAST
		Direction.NORTHWEST:
			return Direction.SOUTHEAST
	return direction


func get_neighbor(direction: Direction) -> Cell:
	match direction:
		Direction.NORTH:
			return north
		Direction.NORTHEAST:
			if north != null:
				return north.east
			if east != null:
				return east.north
		Direction.EAST:
			return east
		Direction.SOUTHEAST:
			if south != null:
				return south.east
			if east != null:
				return east.south
		Direction.SOUTH:
			return south
		Direction.SOUTHWEST:
			if south != null:
				return south.west
			if west != null:
				return west.south
		Direction.WEST:
			return west
		Direction.NORTHWEST:
			if north != null:
				return north.west
			if west != null:
				return west.north
	return null


func get_adjacent_crowns() -> Array[Cell]:
	var touching: Array[Cell] = []
	for direction in Direction.values():
		var neighbor = get_neighbor(direction)
		if neighbor != null && neighbor.type == Type.CROWN:
			touching.append(neighbor)

	return touching
