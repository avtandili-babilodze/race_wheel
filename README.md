# Race Wheel

A solo 3D time-trial racing game built with Godot 4.3. Race a low-poly car
around a circuit against the clock — your best lap time is saved between
sessions.

## Requirements

- [Godot 4.3](https://godotengine.org/download) (GL Compatibility renderer,
  so it runs on modest hardware)

## Running

Open the project in the Godot editor and press **F5**, or from the project
directory:

```sh
godot
```

## Controls

| Key | Action |
| --- | --- |
| W / ↑ | Accelerate |
| S / ↓ | Brake / reverse |
| A / ← and D / → | Steer |
| R | Reset car to the start line |

## Gameplay

- A 3-2-1 countdown starts the race; the lap timer begins on **GO!**
- Four invisible checkpoint gates around the track must be crossed in order,
  so cutting the course or reversing over the line doesn't count.
- Crossing the start/finish line completes the lap. Your best time is saved
  to `user://best_lap.save` and shown on the HUD.

## Project structure

```
scenes/
  main.tscn   Main scene: builds the track, environment, and race flow
  car.tscn    Player vehicle (VehicleBody3D)
  hud.tscn    Lap timer / best time overlay
scripts/
  main.gd          Procedurally builds track, curbs, walls, scenery
  car.gd           Vehicle physics, input, third-person chase camera
  race_manager.gd  Autoload: lap timing, checkpoint order, best-time save
  checkpoint.gd    Checkpoint gate trigger
  hud.gd           HUD labels and countdown messages
```

Everything (track, car, scenery) is generated procedurally in code — there
are no imported 3D assets.
