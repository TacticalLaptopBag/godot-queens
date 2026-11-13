# Queens.gd - AGENTS.md

## Project Overview
2D Godot puzzle game originally cloned from LinkedIn's Tango puzzle. Currently in mid-conversion to Queens clone. Godot 4.7, mobile-focused with desktop support.

**Original**: Tango puzzle (Sun/Moon with constraints)
**Target**: Queens clone (regions, crowns, marks)
**Status**: Bare minimal conversion complete (commit 3a5fece), many dangling wires

## Project Structure

```
src/
├── Core Game Logic
│   ├── cell.gd          # Cell resource - grid cell state
│   ├── puzzle.gd        # Puzzle resource - grid management
│   ├── tile.gd          # Visual tile representation
│   └── board.gd         # Board controller
├── Generation
│   ├── puzzle_generator.gd  # Async puzzle generation
│   └── puzzle_provider.gd   # Puzzle pool manager
├── Persistence
│   └── data_persistence.gd  # Save/load puzzles/scores
├── UI
│   ├── board_ui.gd      # Board positioning
│   ├── selector.gd      # Keyboard/gamepad navigation
│   ├── scoreboard.gd    # High scores
│   └── ui_root.gd       # Theme application
└── Support
    ├── game_theme.gd    # Theme resources
    ├── theme_manager.gd # Theme switching
    ├── util.gd          # Utilities
    └── change.gd        # Undo system
```

## Key Files

### src/cell.gd
Cell resource with:
- **Type enum**: EMPTY, MARK, AUTO_MARK, CROWN
- **Properties**: position, locked, invalid, region
- **Neighbors**: north, south, east, west (8-direction support via get_neighbor)
- **Direction enum**: NORTH, NORTHEAST, EAST, SOUTHEAST, SOUTH, SOUTHWEST, WEST, NORTHWEST
- **Missing**: Constraint enum and methods removed in conversion

### src/puzzle.gd
Manages grid of Cells:
- `_populate(size)` creates cells and links neighbors
- `validate()` checks rules and marks invalid cells
- `_find_invalid_lines()` checks row/column balance (MARK vs CROWN count)
- `get_problem_cells()` aggregates validation issues
- **Dangling**: Calls `cell.has_three_in_a_row()` and `cell.has_illegal_neighbors()` which no longer exist

### src/tile.gd
Visual representation:
- Sprite2D with Mark/Crown sprites
- Click handling: left click cycles EMPTY→MARK→CROWN→EMPTY, right click toggles crown, middle clears
- Long press toggles crown
- Haptics support
- Updates appearance based on cell state

### src/puzzle_generator.gd
Async generation using WorkerThreadPool:
- Pool size: 10 puzzles
- Currently **stubbed**: `_generate_puzzle()` only creates empty grid, TODO comments for region/crown generation
- Missing: Actual Crowns generation logic

### src/board.gd
Main game controller:
- Manages tiles array
- Handles undo via Change stack
- Puzzle completion detection
- Emits signals for UI updates

## Conversion Status

### Completed (commit 3a5fece "Bare minimal conversion")
- Cell.Type changed: SUN/MOON → MARK/AUTO_MARK/CROWN
- Removed Constraint system (EQUAL/OPPOSITE)
- Removed puzzle_solver.gd
- Added region property to Cell
- Direction enum expanded to 8 directions
- Tile visuals updated for Crowns
- GameTheme updated (sun/moon → mark/crown)

### Dangling / Broken
1. **Missing Cell methods**:
   - `has_three_in_a_row()` - referenced in puzzle.gd:82
   - `has_illegal_neighbors()` - referenced in puzzle.gd:75
   - Constraint properties: north_constraint, east_constraint, south_constraint, west_constraint
   - Constraint enum and methods

2. **Persistence mismatch**:
   - `data_persistence.gd` serializes/deserializes constraint properties
   - Cells no longer have these properties
   - Format v2 still expects constraints

3. **Generation stub**:
   - `puzzle_generator.gd::_generate_puzzle()` returns empty grid only
   - No region generation
   - No crown placement logic
   - No validation/solving

4. **Validation incomplete**:
   - Only checks row/column balance
   - Missing Crowns-specific rules:
     - Region constraints (crowns per region?)
     - Adjacent crown rules
     - Three-in-a-row prevention

## Game Rules (Expected for Crowns)

Based on conversion context, Crowns likely involves:
- Grid with regions
- Place crowns in each region according to rules
- Marks indicate something (maybe region boundaries?)
- No three in a row of same type
- Balance constraints per row/column

**Current rules implemented**:
- Row/column must have equal MARK/CROWN count
- Cells can be EMPTY/MARK/CROWN
- Visual feedback for invalid cells

**Missing rules**:
- Region validation
- Adjacent crown constraints
- Puzzle generation with guaranteed solution

## Autoloads (project.godot)
- DataPersistence
- ThemeManager
- ControllerIcons
- PuzzleProvider

## Input Actions
- ui_accept: toggle type
- up/down/left/right: navigation
- toggle: toggle tile type (Space/E)
- moon_toggle: toggle crown (Shift/Q)
- clear: clear tile (Ctrl/F)
- new_game: Escape
- undo: Z

## Key Dependencies
- WorkerThreadPool for async generation
- Persistence addon for save data
- Controller Icons addon
- HapticConfig for vibration

## Known Issues
1. Puzzle generation returns empty grids
2. Deserialization fails for old puzzles with constraints
3. Validation incomplete for Crowns rules
4. No region visualization
5. Scoreboard works but puzzles never complete properly

## Working Directory
- /home/shamilton/dev/godot-crowns
- Git repo with history showing Tango → Crowns conversion

## Next Steps
1. Implement Queens puzzle generation
2. Define region system
3. Implement proper validation rules
4. Fix persistence compatibility
5. Update data_persistence serialization
6. Add region visualization to tiles
