# Queens.gd - AGENTS.md

## Project Overview
2D Godot puzzle game based on LinkedIn's Queens puzzle. Godot 4.7, mobile-focused with desktop support.

**Game**: Queens clone (regions, crowns, marks)
**Status**: Fully functional (commit 42df301, Nov 20 2026)

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
- `_find_crowns_per_row()`, `_find_crowns_per_column()`, `_find_crowns_per_region()`, `_find_touching_crowns()` validate Queens rules
- `get_problem_cells()` aggregates validation issues
- `update_auto_marks()` marks cells that cannot contain crowns

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
- Generates valid Queens puzzles with unique solutions
- Uses backtracking with repair algorithm for uniqueness
- Region growing algorithm ensures connected regions

### src/board.gd
Main game controller:
- Manages tiles array
- Handles undo via Change stack
- Puzzle completion detection
- Emits signals for UI updates

## Conversion Status

### Completed
- Cell.Type: MARK/AUTO_MARK/CROWN (SUN/MOON removed)
- Constraint system removed (EQUAL/OPPOSITE)
- Region system implemented with connected regions
- Direction enum expanded to 8 directions
- Puzzle generation with unique solution guarantee
- Region validation (one crown per region)
- Adjacent crown validation (no touching)
- Row/column validation (one crown per row/column)
- Auto-marking for same row/column/region/adjacent cells
- 5x5, 6x6, 7x7, 9x9 grid sizes supported
- Persistence for puzzles, scores, and in-progress games
- Theme system with colorblind support
- Haptic feedback support
- Multi-platform input (mouse, keyboard, gamepad)
- Backup/restore functionality
- Fastlane metadata for F-Droid

### Current Features
1. **Puzzle generation**: Async generation using WorkerThreadPool with uniqueness validation
2. **Validation**: Complete Queens rules implemented
3. **Persistence**: v1 format, serializes cell type, invalid flag, and region
4. **UI**: Region colors, selection indicators, invalid cell highlighting
5. **Gameplay**: Mark/Crown toggling, auto-marks, undo, clear, drag to mark

## Game Rules (Queens)

Based on LinkedIn's Queens puzzle:

1. **One crown per row and column**: Each row can only have one crown, and each column can only have one crown
2. **One crown per region**: Every region must contain only one crown. Cells in the same region are colored the same
3. **No adjacent crowns**: Crowns cannot be adjacent to one another. Not even diagonally

**Rules implemented**:
- Row/column validation (one crown per row/column)
- Region validation (one crown per region)
- Adjacent crown validation (no touching)
- Auto-marking for cells that cannot contain crowns
- Unique solution guarantee via backtracking and repair algorithm

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
1. Long press timer is Tile-level (may cause issues with drag)
2. ControllerIcons addon uninstalled but input actions still reference it
3. No automated tests

## Working Directory
- Git repo: TacticalLaptopBag/godot-queens
- Current commit: 42df301 (Fix long press interfering with drag)

## Next Steps
1. Test controller support
2. Consider moving long press timer to Board level for better drag handling
3. Add automated tests
