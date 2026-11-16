# Queens Puzzle Generator Plan

## Problem Analysis

Current `src/puzzle_generator.gd` generates unsolvable/difficult puzzles because:
1. **Regions generated after crowns**: Flood fill from crowns creates irregular, unpredictable region shapes
2. **Greedy placement**: `_solve_crown_placement` uses greedy column-first placement with random shuffle, no backtracking
3. **No constraint propagation**: Placement only checks 8-direction adjacency, not row/col/region uniqueness during placement
4. **No solvability guarantee**: No validation that puzzle has unique solution or is deducible without guessing

Current validation in `src/puzzle.gd` checks:
- Crowns per row > 1 (should be exactly 1)
- Crowns per column > 1 (should be exactly 1)  
- Crowns per region > 1 (should be exactly 1)
- Touching crowns (should be 0)

## Design Decisions

### 1. Region Generation First
Generate fixed region partitions before crown placement. Use standard grid partitions:
- For size 6: 2x3 or 3x2 rectangular regions (2x3 = 6 cells per region, 6 regions total)
- For size 8: 2x4 or 4x2 rectangular regions
- For size 9: 3x3 regions (9 regions)
- General: Partition into sqrt(size) x sqrt(size) regions

Regions must be:
- Contiguous (4-direction connected)
- Equal size where possible
- Non-overlapping
- Cover entire grid

### 2. Crown Placement with Backtracking
Place crowns using backtracking search with constraints:
- Exactly one crown per row
- Exactly one crown per column  
- Exactly one crown per region
- No crowns adjacent (8-direction) including diagonally
- Use constraint propagation to prune early

Algorithm:
1. Initialize empty board
2. For each row, try columns in random order
3. Check all constraints before placing
4. Backtrack on failure
5. Repeat with different random seed until solution found

### 3. Solvability Without Guessing

Since puzzle board is empty (no pre-placed crowns), guarantee solvability by:
1. **Solution uniqueness**: Verify puzzle has exactly one valid solution
2. **Logical deduction**: Use constraint propagation to ensure puzzle can be solved via deduction
3. **Difficulty control**: Generate multiple solutions and select ones with appropriate deduction depth

Implementation approach:
- Generate solution using backtracking with random shuffling
- Validate solution uniqueness via exhaustive search (for small grids like 6x6, feasible)
- For larger grids, use heuristic: ensure each step has forced placement via constraint propagation

### 4. Puzzle Structure

Puzzle object contains:
- Grid size
- Region map (pre-computed)
- Solution crowns (for validation/debugging)
- No pre-placed crowns (empty board)

Player solves by placing crowns on empty board. Validation checks solution matches.

## Implementation Plan

### Phase 1: Region Generation
Create `_generate_regions(size)`:
- Input: grid size
- Output: region_map where each cell has region_id
- Algorithm:
  - Determine region dimensions (e.g., 3x2 for 6x6)
  - Assign region_id = (y // region_height) * regions_per_row + (x // region_width)
  - For non-divisible sizes, distribute remainder cells

### Phase 2: Crown Placement
Replace `_solve_crown_placement` with `_find_solution_crowns(size, region_map)`:
- Use backtracking with constraint checking
- Constraints checked at each placement:
  - Column not used
  - Region not used
  - No adjacency with existing crowns
  - Row uniqueness implicit in iteration
- Randomize column order for variety
- Retry with new seed if solution not found

### Phase 3: Validation
Update `_generate_puzzle`:
1. Generate regions
2. Find solution crowns
3. Create puzzle with regions
4. Store solution crowns
5. Validate solution uniqueness (optional for performance)

### Phase 4: Validation Rules
Update `src/puzzle.gd` validation to enforce:
- Exactly one crown per row
- Exactly one crown per column
- Exactly one crown per region
- No adjacent crowns (8-direction)

Current `_find_crowns_per_row/col/region` only checks >1, needs to check ==1

## File Changes

### src/puzzle_generator.gd
- Replace `_solve_crown_placement` with backtracking solver
- Replace `_generate_regions` with pre-defined partition generator
- Update `_generate_puzzle` to use new order
- Remove flood fill logic

### src/puzzle.gd
- Update validation to check exact counts (not just >1)
- Add `_find_missing_crowns_per_row/col/region` for better error reporting

### src/data_persistence.gd
- No changes needed (regions already serialized)

## Risks and Mitigations

1. **Backtracking may fail for some sizes**: Implement multiple retry attempts with different seeds, fallback to smaller grid
2. **Uniqueness check expensive**: For 6x6, exhaustive search is feasible (6! = 720 possibilities). For larger grids, skip uniqueness or sample
3. **Adjacency constraint makes solutions rare**: May need to relax adjacency for larger grids or use heuristic placement
4. **Thread safety**: Generation runs in WorkerThreadPool, ensure RandomNumberGenerator is thread-local

## Validation Plan

1. Generate 100 puzzles for size 6, verify all have valid solutions
2. Verify solution uniqueness for sample of puzzles
3. Test solvability by simulating deduction (optional)
4. Measure generation time (should be <100ms per puzzle)
5. Verify regions are properly partitioned and visualized

## Open Questions

- Exact region partition scheme for non-square sizes?
- Should adjacency be 4-direction or 8-direction? Current code uses 8-direction
- Maximum grid size supported? Backtracking complexity grows factorially
- Difficulty levels? Could adjust by region shape complexity

## Dependencies

- WorkerThreadPool for async generation (existing)
- RandomNumberGenerator for shuffling (existing)
- DataPersistence for storing puzzles (existing)
