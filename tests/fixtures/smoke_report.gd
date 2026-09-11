## The pass/fail ledger `tests/integration/run_smoke.gd` and its topic modules
## write into.
##
## It exists as its own class so a module can record a result without depending on
## the suite that runs it. The suite loads the modules; if the modules had to name
## the suite back to reach `check`, the two would refer to each other and neither
## would resolve.
class_name SmokeReport
extends RefCounted

var failures := 0


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		push_error("FAIL: %s" % description)
