# In-Progress Puzzle Persistence Plan

## Context
PuzzleProvider currently serves puzzles from a generated pool stored in DataPersistence. PuzzleProvider.get_puzzle() pops the first puzzle from the pool and removes it from persistence. No in-progress state is tracked.

Board loads a puzzle on _ready via PuzzleProvider.get_puzzle(grid_size). New Game button also requests a new puzzle from provider. Board emits puzzle_completed when all crowns are placed.

## Goal
Save current puzzle state per grid size, resume it on next request, and delete it on completion.

## Decisions
- Resume in-progress on New Game: Yes, per user confirmation.
- Save frequency: Save on every cell type change.
- Storage: Separate persistence keys per size, not the pool array.
- Completion cleanup: Delete in-progress on puzzle_completed.

## Data Flow

### DataPersistence changes
Add in-progress key format:
```gdscript
const IN_PROGRESS_FMT := "in_progress_%d"
```
Methods:
- `save_in_progress_puzzle(puzzle)`: serialize via existing `serialize_puzzle`, store under IN_PROGRESS_FMT % size, call `save()`.
- `load_in_progress_puzzle(size)`: return deserialized Puzzle if key exists, else null.
- `delete_in_progress_puzzle(size)`: erase key if present, call `save()`.

Serialization uses existing v1 format: grid_size, cell type, invalid, region. solution_crowns is not persisted; not needed for play.

### PuzzleProvider changes
`get_puzzle(size)`:
1. Attempt `DataPersistence.load_in_progress_puzzle(size)`. If puzzle exists, return it.
2. Otherwise fall back to generator pool: get puzzle from `_generators_dict[size]`.
3. If puzzle obtained from generator, persist it as in-progress via `DataPersistence.save_in_progress_puzzle(puzzle)` to establish ownership.
4. Return puzzle.

No change to pool loading; generator queue_generation continues to pre-populate pool via existing `fetch_puzzles`.

### Board changes
- Save on edit: In `_on_cell_type_changed(cell, old_type)`, after undo handling, call `DataPersistence.save_in_progress_puzzle(puzzle)` when not undoing. This satisfies save-on-every-cell-change.
- Completion cleanup: In `_update_state()`, after `puzzle_completed.emit(start_ticks, end_ticks)`, call `DataPersistence.delete_in_progress_puzzle(grid_size)`. This removes the in-progress entry for the completed size.

Alternative coupling: PuzzleProvider could listen to board.puzzle_completed to delete in-progress. Keeping deletion in Board keeps provider stateless.

### New Game behavior
`new_game_button.gd` calls `PuzzleProvider.get_puzzle(board.grid_size)` then sets `board.puzzle = puzzle`. With the above change, get_puzzle will return the in-progress puzzle if present, otherwise a fresh generated puzzle. This matches resume behavior.

## Edge Cases
- Size change: In-progress puzzles are keyed per size, so switching sizes loads correct state.
- First load with no in-progress: Provider returns generated puzzle and saves it as in-progress immediately, establishing baseline.
- Undo/clear: Saves still occur; undo reverts cell type then saves reverted state.
- App close: Last cell change was persisted; no additional save needed.
- Pool isolation: In-progress puzzles use separate keys, so generator `fetch_puzzles` / `store_puzzle` remain unaffected.

## Validation
- Request puzzle for size with existing in-progress → returns same puzzle instance data.
- Edit cell → DataPersistence contains updated serialized puzzle for that size.
- Complete puzzle → in-progress key removed.
- New request after completion → loads fresh puzzle from generator pool.

## Open Questions
None; decisions confirmed with user.

## Files to modify
- `src/data_persistence.gd`
- `src/puzzle_provider.gd`
- `src/board.gd`
