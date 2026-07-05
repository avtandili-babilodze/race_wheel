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

- The main menu lets you pick a car and a track. Cars range from the
  **Thunder V8** muscle car to the **Apex F1** single-seater, each with its
  own speed, grip, and handling. Tracks range from the flat-out **Speedway
  Oval** to the 4.4 km **Colossus**, each shown with its outline and your
  best time. Press **Esc** in a race to return.
- Every track is generated from a list of centerline points in
  `race/track_data.gd`, and every car from a spec in `car/car_data.gd`;
  add an entry there to add a new track or car.
- A 3-2-1 countdown starts the race; the lap timer begins on **GO!**
- Six invisible checkpoint gates around the track must be crossed in order,
  so cutting the course or reversing over the line doesn't count.
- Crossing the start/finish line completes the lap. Your best time per
  track is saved to `user://best_lap_<n>.save` and shown on the HUD.

## Project structure

```
run.sh / run.bat  One-click launchers (find or download Godot, then play)
autoload/
  race_manager.gd  Global race state: lap timing, checkpoints, best times
race/
  race.tscn/.gd    Race scene: builds track, environment, and race flow
  track_data.gd    Track catalog: centerline points for each circuit
  checkpoint.gd    Checkpoint gate trigger
car/
  car.tscn/.gd     Player vehicle: physics, input, chase camera
  car_data.gd      Car catalog: tuning, colors, and menu profile per model
  car_body.gd      Procedural 3D bodies for each car model
ui/
  menu/            Car and track selection menu (startup scene)
  hud/             Lap timer / best time overlay

Folders are organized by feature — each scene lives beside its script, so a
feature can be extended or removed as a unit. New game features get a new
top-level folder (e.g. audio/, opponents/); shared art or sound assets
would go in assets/.
```

Everything (track, car, scenery) is generated procedurally in code — there
are no imported 3D assets.
