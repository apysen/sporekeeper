class_name RunSnapshot
extends RefCounted

## A run in progress, in a form that survives the game being closed.
##
## The snapshot holds identity - which mode, which seed, how far in - and one
## dictionary per system that owns state worth keeping. It does not know what is in
## those dictionaries. Each system captures and applies its own, because the fields
## that matter are the ones that system understands, and a snapshot that listed them
## would have to be edited every time one of them gained a field.
##
## **What is deliberately not in here: anything alive on the battlefield.** Enemies,
## projectiles, pickups, damage numbers and in-flight commands are pooled transient
## state that the wave the snapshot restores will produce again from the clock it
## restores. That is what makes the restored run a continuation rather than a
## reconstruction of one frame that happened to be serializable.
##
## A save taken at a wave break finds that state empty anyway. One taken on the way out
## of a run mid-wave does not, and discards it: the run comes back at the right minute
## of the right wave, on the ground it held, with the arena briefly clear.

## Systems whose state is kept, and the key each one is stored under. Named as a
## constant so the snapshot, the round trip and the tests agree on the set.
const SYSTEM_KEYS := [
	"progression", "evolutions", "metabolism", "player", "waves", "field", "cankers",
	"trial", "stats",
]

var mode := RunMode.Id.QUICK
var run_seed := 0
## The wave the run is about to face. Kept out of the `waves` dictionary as well as
## in it, so a menu can say what is waiting without asking the wave director to
## interpret its own save.
var wave_number := 1
var elapsed_seconds := 0.0
var saved_unix_time := 0

var systems := {}


func set_system(key: String, state: Dictionary) -> void:
	systems[key] = state


## The state a system stored, or empty when this snapshot has none for it - which is
## a save written before that system kept anything, and leaves the system at whatever
## a fresh run gave it.
func get_system(key: String) -> Dictionary:
	var state: Variant = systems.get(key, {})
	return state if state is Dictionary else {}


func to_dictionary() -> Dictionary:
	var data := {
		"mode": mode,
		"run_seed": run_seed,
		"wave_number": wave_number,
		"elapsed_seconds": elapsed_seconds,
		"saved_unix_time": saved_unix_time,
	}
	for key in SYSTEM_KEYS:
		data[key] = get_system(key)
	return data


static func from_dictionary(data: Dictionary) -> RunSnapshot:
	var snapshot := RunSnapshot.new()
	snapshot.mode = clampi(int(data.get("mode", RunMode.Id.QUICK)), RunMode.Id.QUICK, RunMode.Id.CAMPAIGN)
	snapshot.run_seed = int(data.get("run_seed", 0))
	snapshot.wave_number = maxi(1, int(data.get("wave_number", 1)))
	snapshot.elapsed_seconds = float(data.get("elapsed_seconds", 0.0))
	snapshot.saved_unix_time = int(data.get("saved_unix_time", 0))
	for key in SYSTEM_KEYS:
		var state: Variant = data.get(key, {})
		snapshot.set_system(key, state if state is Dictionary else {})
	return snapshot
