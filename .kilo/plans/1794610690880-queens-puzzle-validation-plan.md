# Queens Puzzle Validation Plan

## Overview
Update `src/puzzle.gd` to implement Queens puzzle rules and remove Tango-specific code. Queens requires: one crown per row, one crown per column, one crown per region, and no crowns may touch even diagonally.

## Context
- Current code has Tango remnants: `_find_invalid_lines()` checks MARK/CROWN balance, references to non-existent `cell.has_three_in_a_row()` and `cell.has_illegal_neighbors()`
- Cell.Type includes EMPTY, MARK, AUTO_MARK, CROWN
- MARK is user-placed mark indicating cell cannot have crown
- AUTO_MARK is automatic mark for cells in same row/column as crown and 8 neighbors
- Regions are assigned by generator via flood fill from crowns
- Puzzle completion currently checks `is_filled()` which requires all cells non-empty

## Decisions Resolved
- Keep MARK and AUTO_MARK types for hint system
- Cells need not be filled; only crown placement matters
- Regions are static per puzzle, assigned during generation
- Marks block crowns: cannot place crown on MARK/AUTO_MARK cell
- Remove MARK/CROWN balance check completely
- Completion requires all crowns placed AND validation passes
- Validation uses dedicated checks per rule
- Crowns only need validation for touching, not marks
- Auto-marks are automatic with configurable boolean flag
- Auto-marks apply to row/col + 8 neighbors when crown placed
- Auto-marks removed when crown removed
- Puzzle.gd handles auto-mark updates
- Region validation checks at most one crown per region
- Validation marks all involved cells invalid when violation occurs
- Use assigned region IDs, not dynamic computation
- Update board.gd completion check to crown count
- Keep get_neighbor for 8-direction support
- Remove all Tango-specific code
- Mark both crowns when touching violation occurs
- Completion requires valid puzzle AND correct crown count

## Affected Files
- `src/puzzle.gd` - Main validation logic
- `src/board.gd` - Completion criteria update

## Plan

### 1. Remove Tango-specific validation
- Remove `_find_invalid_lines()` function
- Remove `_find_illegal_constraints()` function  
- Remove calls to `cell.has_three_in_a_row()` and `cell.has_illegal_neighbors()`
- Remove `LineType` enum
- Simplify `get_problem_cells()` to only Queens rules

### 2. Implement Queens validation rules

#### Rule 1: One crown per row
- Create `_find_crowns_per_row()` helper
- Iterate each row, count crowns
- Mark all crowns in row as invalid if count > 1
- Return array of invalid cells

#### Rule 2: One crown per column  
- Create `_find_crowns_per_column()` helper
- Iterate each column, count crowns
- Mark all crowns in column as invalid if count > 1
- Return array of invalid cells

#### Rule 3: One crown per region
- Create `_find_crowns_per_region()` helper
- Group cells by region ID
- Count crowns per region
- Mark all crowns in region as invalid if count > 1
- Return array of invalid cells

#### Rule 4: No crowns touch
- Create `_find_touching_crowns()` helper
- For each crown, check 8 neighbors via `get_neighbor()`
- If neighbor is crown, mark both as invalid
- Return array of invalid cells

### 3. Auto-mark system
- Add `auto_marks_enabled: bool = true` property to Puzzle
- Add `update_auto_marks()` method:
  - Clear all AUTO_MARK cells to EMPTY (preserve manual MARK)
  - For each crown cell:
    - Mark same row cells as AUTO_MARK (skip crown cell)
    - Mark same column cells as AUTO_MARK (skip crown cell)
    - Mark 8 neighbors as AUTO_MARK
  - Preserve manual MARK cells
- Call `update_auto_marks()` after cell type changes
- Ensure auto-mark cleanup when crown removed

### 4. Update validation flow
- `get_problem_cells()` should:
  - Call each validation rule helper
  - Aggregate results
  - Remove duplicates
- `validate()` marks cells invalid based on problem cells
- Validation should not check MARK cells for crown placement conflicts

### 5. Update completion criteria
- Modify `is_filled()` or create `has_all_crowns_placed()`:
  - Count crown cells
  - Return true if count == grid_size
- Update `board.gd _update_state()` to check:
  - `puzzle.validate()` passes
  - Crown count equals grid_size
- Remove dependency on `is_filled()`

### 6. Data persistence compatibility
- Current serialization includes region but not solution_crowns
- Keep existing v1 format compatible
- No changes needed to data_persistence.gd for validation

## Validation Steps
1. Create test puzzle with known violations
2. Verify row violation detection marks both crowns
3. Verify column violation detection works
4. Verify region violation detection works  
5. Verify touching detection includes diagonals
6. Verify auto-marks apply correctly on crown placement
7. Verify auto-marks clear on crown removal
8. Verify completion triggers when all crowns placed correctly

## Risks
- Auto-mark updates may cause performance issues on large grids
- Manual MARK preservation during auto-mark refresh needs careful handling
- Validation marking both cells in violation may cause double-counting
- Existing saved puzzles may have old validation state

## Open Questions
None - all design decisions resolved via user input
