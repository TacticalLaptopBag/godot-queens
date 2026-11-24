<h1 align="center">

  ![Queens.gd Icon](icon.png)

  Queens.gd
</h1>

The classic LinkedIn puzzle, [Queens][queens], reimplemented in Godot.
Select from 5x5, 6x6, 7x7, or 9x9 grids.
Puzzles are randomly generated, and are guaranteed to have a single unique solution.

No internet connection required for standalone builds.

Don't want to download? Play in your web browser on [itch.io][itch]

Code based on [Tango.gd][tango.gd].

![Screenshot of Queens.gd gameplay](fastlane/metadata/android/en-US/images/phoneScreenshots/1.png)

## How to Play

Your objective is to place a crown in each region on the board.
Every puzzle has one unique solution that is guaranteed to be solvable.

There are three rules you must follow while filling the board, as shown below.

### Rule 1: One crown per row and column
Each row can only have one crown, and each column can only have one crown.

### Rule 2: One crown per region
Every region must contain only one crown. Cells in the same region are colored the same.

### Rule 3: No adjacent crowns
Crowns cannot be adjacent to one another. Not even diagonally.

## Controls

### Mouse

 * Left click: Toggle Mark -> Crown -> Blank
 * Right click: Toggle Crown -> Blank
 * Middle click: Clear tile


### Keyboard

 * WASD / Arrow keys: Select tile
 * Space / E: Toggle Mark -> Crown -> Blank
 * Shift / Q: Toggle Crown -> Blank
 * CTRL / F: Clear tile
 * Z: Undo
 * Escape: New Game


### Gamepad

All face buttons assume XBox-style layout

 * Left stick / D-Pad: Select tile
 * (A): Toggle Mark -> Crown -> Blank
 * (X): Toggle Crown -> Blank
 * (Y): Clear tile
 * (B): Undo
 * Menu: New Game


## AI Usage Disclaimer

The following local models were used for code assistance:
* `google/gemma-4-31b-qat`
* `meta/muse-glimmer`

Claude Sonnet 5.5 was used to create the puzzle generator.

No AI was used in the creation of assets.


## TODO:
- [ ] Test controller support


[queens]: https://www.linkedin.com/games/queens/
[tango.gd]: https://github.com/TacticalLaptopBag/godot-tango
[itch]: https://tacticallaptopbag.itch.io/queens
