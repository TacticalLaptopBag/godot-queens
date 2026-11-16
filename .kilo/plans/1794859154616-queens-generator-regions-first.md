# Queens Puzzle Generator - Regions First Reimplementation Plan

## Overview
Reimplement `src/puzzle_generator.gd` to generate regions first, then place crowns with guaranteed unique solution and no guessing. Current implementation places crowns first then flood fills regions, resulting in multiple solutions.

## Context
- Current generator: `_solve_crown_placement()` places non-attacking crowns, then `_generate_regions()` flood fills from crown positions
- This creates valid boards but does not guarantee unique solution
- User requirement: regions generated first, then crowns placed
- Rules: one crown per row, column, region; no adjacent crowns (including diagonally)
- Unique solution required per puzzle
- No guessing when solving

## Design Decisions

### Region Generation First
Generate connected regions before crown placement using random growth from seeds:
1. Start with n seed cells (one per region), ensure no two seeds adjacent
2. Grow regions randomly into unassigned cells via BFS/DFS
3. Ensure each region remains orthogonally connected
4. Regions can vary in size (1 cell minimum, no equal area requirement)

### Crown Placement via Constraint Backtracking
After regions are fixed:
1. Use backtracking to find crown placement satisfying all constraints
2. Constraints: one crown per row, column, region; no 8-direction adjacency
3. Find first valid solution
4. Count total solutions to ensure uniqueness
5. If multiple solutions, modify region layout and retry

### Uniqueness Enforcement
Constructive backtracking with solution counting:
- Find one solution via backtracking
- Count all solutions up to limit (2 for uniqueness check)
- Accept only if exactly one solution exists
- Regenerate regions if multiple solutions found

## Affected Files
- `src/puzzle_generator.gd` - complete reimplementation of generation pipeline
- `src/puzzle.gd` - may need solution counting helper methods
- No changes to persistence, validation, or UI

## Implementation Plan

### 1. Region Generation (`_generate_regions_first(size)`)
Generate n connected regions covering size×size grid:

```gdscript
func _generate_regions_first(size: int) -> Array:
    # Step 1: Place seeds
    # Ensure seeds not adjacent (to allow growth)
    # Assign each seed a unique region ID
    
    # Step 2: Grow regions
    # While unassigned cells remain:
    #   Pick random unassigned cell adjacent to assigned region
    #   Assign to random neighboring region
    #   Ensure region stays connected (optional validation)
    
    # Step 3: Validate regions
    # Each region must be orthogonally connected
    # Each region must have at least 1 cell
    # All cells assigned
```

Seed placement:
- Randomly select n cells with no adjacency constraint
- Or place on checkerboard pattern then randomize
- Use Fisher-Yates shuffle for randomness

Growth algorithm:
- Maintain queue of frontier cells
- Randomly pick frontier cell and assign to random adjacent region
- Shuffle candidates each iteration
- Continue until all cells assigned

Validation:
- BFS check each region for connectivity
- If disconnected, retry generation

### 2. Crown Placement with Backtracking (`_find_unique_crown_placement(size, region_map)`)

```gdscript
func _find_crown_placement(size: int, region_map: Array, rng: RandomNumberGenerator) -> Array[Vector2i]:
    # Backtracking over rows
    # For each row, try columns in random order
    # Check constraints:
    #   - Column not used
    #   - Region not used
    #   - No adjacency with placed crowns (8-direction)
    #   - Cell exists in region
```

Backtracking details:
- Track used columns and used regions
- For each row, generate candidate columns
- Shuffle candidates with rng
- Check adjacency: `abs(dx) <= 1 and abs(dy) <= 1`
- If valid, recurse to next row
- Backtrack on failure

### 3. Solution Counting for Uniqueness (`_count_solutions(size, region_map, limit)`)

Count solutions up to limit (2):
- Use same backtracking as placement
- Count solutions found
- Stop early if count >= limit
- Return count

### 4. Generation Loop (`_generate_puzzle(size)`)

```gdscript
func _generate_puzzle(size: int) -> Puzzle:
    var max_attempts = 100
    
    for attempt in range(max_attempts):
        # Generate regions
        var region_map = _generate_regions_first(size)
        if region_map == null:
            continue
            
        # Find crown placement
        var rng = RandomNumberGenerator.new()
        rng.randomize()
        var crowns = _find_crown_placement(size, region_map, rng)
        
        if crowns.is_empty():
            continue
            
        # Check uniqueness
        var solution_count = _count_solutions(size, region_map, 2)
        if solution_count == 1:
            # Valid puzzle found
            return _build_puzzle(size, region_map, crowns)
    
    # Failed after max attempts
    return null
```

### 5. Puzzle Construction

Build Puzzle resource:
- Create Puzzle with size
- Assign region IDs to each cell from region_map
- Store solution crowns for validation
- Return puzzle

## Integration Points

### Async Generation
Keep existing WorkerThreadPool infrastructure:
- `_generate_and_store()` unchanged
- `_top_up_pool()` unchanged
- Only `_generate_puzzle()` implementation changes

### Puzzle Object
`Puzzle.solution_crowns` already exists
No changes needed to cell structure
Region assignment via `cell.region = region_map[y][x]`

## Validation Steps

1. Generate 10 puzzles for size 6
2. Verify each has exactly one solution
3. Verify no adjacent crowns
4. Verify one crown per row/column/region
5. Verify regions are connected
6. Test generation time < 1 second per puzzle
7. Test with sizes 4, 5, 6, 7, 8
8. Verify puzzles solvable without guessing (optional: logical deduction check)

## Risks

1. **Performance**: Solution counting is exponential. Mitigation: limit to 2 solutions, use heuristics (smallest region first), early exit
2. **Generation failure**: Regions may make puzzle unsolvable. Mitigation: max attempts, regenerate regions
3. **Bias**: Random growth may create unbalanced regions. Mitigation: randomize order, shuffle candidates
4. **Size limits**: Larger grids may be intractable. Mitigation: size-dependent attempt limits, fallback to simpler generation for large sizes

## Open Questions

- Grid sizes supported? Current default is 6, pool_size 10
- Should region generation ensure minimum region size?
- How to handle generation timeouts in worker threads?
- Should we cache successful region layouts?

## Dependencies

No external dependencies. Uses existing:
- RandomNumberGenerator
- WorkerThreadPool
- Mutex/Semaphore for thread safety
- DataPersistence for storage

## Testing Approach

Unit tests for:
- Region connectivity validation
- Crown placement constraints
- Solution counting accuracy
- Uniqueness guarantee

Integration tests for:
- Full generation pipeline
- Async generation
- Persistence compatibility
