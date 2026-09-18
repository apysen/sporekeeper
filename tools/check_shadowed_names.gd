extends SceneTree

## Runs `ShadowedNames.scan` on its own, for a sweep without starting a run.
##
## The same scan runs inside `tests/integration/run_smoke.gd`, so an ordinary suite
## pass already covers it. This entry exists for the case the suite cannot serve: a
## tree that does not boot, or a scan wanted before anything is launched.
##
## Run: godot --headless --script tools/check_shadowed_names.gd

func _initialize() -> void:
	var collisions := ShadowedNames.scan()
	for collision in collisions:
		push_error("SHADOWED: %s" % collision)
	if collisions.is_empty():
		print("SHADOWED_NAMES: PASS (no declaration shadows an inherited name)")
	else:
		print("SHADOWED_NAMES: FAIL (%d)" % collisions.size())
	quit(0 if collisions.is_empty() else 1)
