extends SceneTree

## What Campaign's pressure curve actually produces, minute by minute.
##
## Density is not one number: it is the spawn interval, the pack size and the
## enemy scaling together, and all three read the same pressure progress. This
## prints them side by side with Quick so a change to the curve can be judged
## against the mode it is being compared to rather than by feel alone.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/run/phase_b_prototype.tscn")
	await process_frame
	await process_frame
	var p := current_scene as PhaseBPrototype
	p.set_process(false)
	p.combat.set_process(false)
	for mode in [PhaseBRunMode.Id.QUICK, PhaseBRunMode.Id.CAMPAIGN]:
		var w := p.wave_director
		w.configure_mode(mode)
		var label := "QUICK   " if mode == PhaseBRunMode.Id.QUICK else "CAMPAIGN"
		for minute in [1, 2, 3, 5, 8, 10, 15, 20, 25]:
			var t := float(minute) * 60.0
			if t > w.run_duration_seconds:
				continue
			w.elapsed_seconds = t
			var progress: float = w._pressure_progress()
			var interval: float = lerpf(
				w.early_spawn_interval_seconds, w.late_spawn_interval_seconds, progress
			)
			var pack := w.late_pack_size if progress > w.late_pack_progress else w.regular_pack_size
			print("%s t=%2dm progress=%.2f interval=%.2fs pack=%d per_sec=%.2f health=x%.2f" % [
				label, minute, progress, interval, pack, float(pack) / interval,
				lerpf(1.0, w.final_health_scale, progress),
			])
	quit(0)
