class_name RunLaunch
extends RefCounted

## Whether the run scene about to load is a new run or the saved one being continued.
##
## The menu and the run are two scenes with nothing between them but
## `change_scene_to_file`, so the choice travels the same way the mode does - as a
## flag on `Engine` rather than as an argument nothing can pass. It is a one-shot:
## `consume` clears it, so a run that ends and drops the player back to the menu
## cannot start the next one by resuming something.

const META_KEY := "sporekeeper_resume_saved_run"
## Set by the menu on its way into the run scene, so the run can tell a game being
## played from a scene a probe loaded. Forty-one test scripts load `run.tscn`
## directly; none of them goes past the menu, and none of them should be able to
## write over the player's save by driving a wave boundary.
const LAUNCHED_KEY := "sporekeeper_launched_from_menu"


## Marks the run about to load as one the player asked for. Consumed by the run, so
## a probe that loads the run scene afterwards is not mistaken for a second launch.
static func mark_launched_from_menu() -> void:
	Engine.set_meta(LAUNCHED_KEY, true)


## True once per launch. Reading it is what clears it.
static func consume_launched_from_menu() -> bool:
	if not Engine.has_meta(LAUNCHED_KEY):
		return false
	Engine.remove_meta(LAUNCHED_KEY)
	return true


static func request_resume() -> void:
	Engine.set_meta(META_KEY, true)


static func request_new_run() -> void:
	Engine.remove_meta(META_KEY)


## True once per request. Reading it is what clears it.
static func consume_resume() -> bool:
	if not Engine.has_meta(META_KEY):
		return false
	Engine.remove_meta(META_KEY)
	return true
