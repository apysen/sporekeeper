class_name RunMode
extends RefCounted

enum Id {
	QUICK,
	CAMPAIGN,
}

const META_KEY := "sporekeeper_run_mode"


static func set_selected(mode: int) -> void:
	Engine.set_meta(META_KEY, clampi(mode, Id.QUICK, Id.CAMPAIGN))


static func get_selected() -> int:
	if not Engine.has_meta(META_KEY):
		return Id.QUICK
	return clampi(int(Engine.get_meta(META_KEY)), Id.QUICK, Id.CAMPAIGN)


## Named `mode_name` rather than `get_name`: a static called `get_name` loses to the
## one every script inherits, which takes no arguments, so `RunMode.get_name(mode)`
## resolved to the built-in and this function was unreachable.
static func mode_name(mode: int) -> String:
	return "CAMPAIGN" if mode == Id.CAMPAIGN else "QUICK"
