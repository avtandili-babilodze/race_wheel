# Race Wheel

A solo 3D time-trial racing game built with Godot 4.3. Race a low-poly car
around a circuit against the clock — your best lap time is saved between
sessions.

## Running

The easiest way is the bundled launcher — it finds an installed Godot 4.3,
or downloads a local copy on first run (~70 MB, kept in `.godot-bin/`, no
system install needed):

- **Linux / macOS:** `./run.sh`
- **Windows:** double-click `run.bat`

You can point the launcher at a specific Godot binary with the `GODOT`
environment variable. On Windows the game log is written to
`racewheel-log.txt`, and the launcher shows the tail of it if the game
crashes.

Alternatively, open the project in the
[Godot 4.3](https://godotengine.org/download) editor and press **F5**. The
project uses the GL Compatibility renderer, so it runs on modest hardware.

## Controls

| Key | Action |
| --- | --- |
| W / ↑ | Accelerate |
| S / ↓ | Brake / reverse |
| A / ← and D / → | Steer |
| R | Reset car to the start line |

## Gameplay

- The main menu lets you pick one of three tracks — **Grand Circuit** (a
  GP-style lap with sweepers, esses, and a chicane), **Speedway Oval**
  (flat-out), and **Switchback Snake** (tight hairpins) — each shown with
  its outline and your best time. Press **Esc** in a race to return.
- Every track is generated from a list of centerline points in
  `scripts/track_data.gd`; add a new entry there to add a new track.
- A 3-2-1 countdown starts the race; the lap timer begins on **GO!**
- Six invisible checkpoint gates around the track must be crossed in order,
  so cutting the course or reversing over the line doesn't count.
- Crossing the start/finish line completes the lap. Your best time per
  track is saved to `user://best_lap_<n>.save` and shown on the HUD.

## Project structure

```
run.sh / run.bat  One-click launchers (find or download Godot, then play)
scenes/
  menu.tscn   Track selection menu (startup scene)
  main.tscn   Race scene: builds the track, environment, and race flow
  car.tscn    Player vehicle (VehicleBody3D)
  hud.tscn    Lap timer / best time overlay
scripts/
  menu.gd          Track list with outline previews and best times
  track_data.gd    Track catalog: centerline points for each circuit
  main.gd          Procedurally builds track, curbs, walls, scenery
  car.gd           Vehicle physics, input, third-person chase camera
  race_manager.gd  Autoload: lap timing, checkpoints, per-track best times
  checkpoint.gd    Checkpoint gate trigger
  hud.gd           HUD labels and countdown messages
```

Everything (track, car, scenery) is generated procedurally in code — there
are no imported 3D assets.
