class_name PhaseBAudioSettings
extends Node

@export_group("Buses")
## Name of the AudioServer bus used by gameplay sound effects.
@export var sfx_bus_name: StringName = &"SFX"
## Name of the AudioServer bus used by the looping ambient theme.
@export var music_bus_name: StringName = &"Music"

@export_group("Slider Output Caps")
## Linear output reached when the pause-menu SFX slider displays 100%.
@export_range(0.0, 1.0, 0.01) var sfx_max_linear_volume := 0.20
## Linear output reached when the pause-menu Music slider displays 100%.
@export_range(0.0, 1.0, 0.01) var music_max_linear_volume := 0.20
