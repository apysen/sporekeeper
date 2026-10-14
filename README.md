# Sporekeeper

Sporekeeper is a fixed-screen territory-control survivor game built with Godot 4.7. Grow and defend Plant territory, fight off waves of hostile creatures, and develop a build of paths, upgrades, relics, and evolutions. This repository contains the playable prototype and its design and engineering notes.

## Requirements

- Godot 4.7
- PowerShell 7 to run the test suite (`pwsh`)

## Run the game

Open this folder in Godot and run the project, or launch it from a terminal:

```powershell
godot --path .
```

The project starts at the home screen. The main gameplay scene is `scenes/run/run.tscn`.

## Controls

- Move with **WASD** or the **arrow keys**.
- Your Cane attacks automatically. Selecting Vine changes its targeting behavior.
- Use the right-hand panel to spend Biomass.
- Choose upgrades and relics when a draft pauses the run.
- Press **R** to restart.

The run scene's prototype debug controls are documented in [docs/run_composition.md](docs/run_composition.md).

## Tests

Run the full suite from the project root:

```powershell
pwsh scripts/run_tests.ps1
```

Useful options include listing discovered tests, skipping performance probes, filtering by test filename, and choosing a Godot executable:

```powershell
pwsh scripts/run_tests.ps1 -ListOnly
pwsh scripts/run_tests.ps1 -SkipPerformance
pwsh scripts/run_tests.ps1 -Filter "save_*" -SkipPerformance
pwsh scripts/run_tests.ps1 -GodotExecutable "C:\path\to\godot.exe"
```

Some rendering probes require a visible window; the runner detects these and starts them windowed.

## Project notes

- [Run composition and controls](docs/run_composition.md)
- [Project structure and code placement](docs/project_structure.md)
- [Territory simulation architecture](docs/territory_simulation_architecture.md)
- [Benchmarks and performance notes](docs/benchmarks/README.md)
- [Game design document](docs/Territory_Survivor_Game_Design_Document.docx)

