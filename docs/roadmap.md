### How to add new features to the game engine

- **New room feature**: add a constant, give it a letter in `ParseMap`'s `"RUDSFVCT"` / `"07683214"` strings, a chance in `Populate`, a drawing in `DrawArena`, and a `CASE` in `Treasure`.
- **New magic effect**: add a `CASE` in `UseMagic` and document the number for module writers.
- **New module keyword**: add a `CASE` in `LoadModule`, set a default at the top of that routine, and clamp the value.
- **Wider or taller grids**: `cell()` and the `GRID` limit are 14×10; the map screen scales automatically, but `SaveGame` row lines must stay under 255 characters (each cell can take up to 14 characters).
