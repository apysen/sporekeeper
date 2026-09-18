## Finds declarations whose name loses to one every script already inherits.
##
## `static func get_name(mode: int)` parses cleanly, imports cleanly, and is
## unreachable: `get_name()` exists on the script object, takes no arguments, and wins
## at the call site. The call then fails at runtime with *"Expected 0 argument(s)"* -
## in a build that reported no errors at all.
##
## That is the whole reason this exists. Every other mistake in this project is caught
## by `--import`, which parses every script and names the file and line. This one is
## invisible to it, and it has been shipped twice: once in `RunMode`, where a probe
## carried a duplicate of the shadowed body with a comment explaining why, and once in
## `EvolutionDescriptions`, where it cost sixty-four runtime errors and a failed check.
##
## The scan is its own class because it has two callers: `tools/check_shadowed_names.gd`
## runs it alone, and `tests/integration/run_smoke.gd` runs it with the suite - a check
## that only runs when someone remembers to run it is a check that will be forgotten.
class_name ShadowedNames
extends RefCounted

## Names a script inherits that take no arguments, so a same-named declaration taking
## one or more is silently unreachable. Not exhaustive - it is the set that has
## plausibly-useful names, which is where the collisions happen.
const INHERITED := [
	"get_name", "set_name", "get_class", "get_script", "get_path", "get_rid",
	"get_meta", "get_instance_id", "get_parent", "get_children", "get_owner",
	"get_tree", "get_index", "get_groups", "get_position", "get_rotation",
	"get_scale", "get_transform", "get_global_position", "get_viewport",
	"get_window", "get_base_script", "get_global_name", "get_local_scene",
	"duplicate", "free", "new", "to_string", "notification", "is_class",
]

## The directories a collision can be shipped in. `res://scenes` and `res://data` hold
## composition and authored Resources, not declarations.
const ROOTS := ["res://src", "res://tests", "res://tools"]


## One message per collision found, each naming the file, the line and the name.
## Empty means every declaration in `ROOTS` is reachable.
static func scan() -> PackedStringArray:
	var collisions := PackedStringArray()
	for root in ROOTS:
		for path in _script_paths(root):
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				continue
			var line_number := 0
			while not file.eof_reached():
				var line := file.get_line()
				line_number += 1
				var declared := _declared_name(line)
				if declared.is_empty() or not INHERITED.has(declared):
					continue
				collisions.append(
					"%s:%d declares '%s', which every script already inherits"
						% [path, line_number, declared]
				)
			file.close()
	return collisions


## The function name a `func` line declares, or "" for any other line. Only
## declarations at the top level of a script are checked: an inner class is reached
## through its own name and does not inherit the outer script's surface.
static func _declared_name(line: String) -> String:
	var body := line
	if body.begins_with("static func "):
		body = body.substr(12)
	elif body.begins_with("func "):
		body = body.substr(5)
	else:
		return ""
	var open_paren := body.find("(")
	if open_paren <= 0:
		return ""
	var declared := body.substr(0, open_paren).strip_edges()
	# A declaration taking no arguments is an override rather than a collision.
	var close_paren := body.find(")", open_paren)
	if close_paren == open_paren + 1:
		return ""
	return declared


static func _script_paths(root: String) -> PackedStringArray:
	var found := PackedStringArray()
	var directory := DirAccess.open(root)
	if directory == null:
		return found
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		var path := "%s/%s" % [root, entry]
		if directory.current_is_dir():
			found.append_array(_script_paths(path))
		elif entry.ends_with(".gd"):
			found.append(path)
		entry = directory.get_next()
	directory.list_dir_end()
	return found
