class_name RunStats
extends RefCounted

## What everything in the run contributed, for the result screen.
##
## One row per contributor -- the Cane, each Adaptation, the relics, Seeds and
## Overgrow -- carrying damage dealt, kills, when it first did anything, and how
## much Green it grew. Beside the rows, what the run did for Grandma and for the
## ground: damage she took and the share Canopy and Bark kept off her, what she healed,
## and how much Green the Aftergrowth shield saved from erosion.
##
## It only counts. Nothing reads it back into the game, so it can never change a
## run's outcome -- the systems that produce each number report into it at the one
## place that number is decided, and the result panel reads it once at the end.
##
## Green is counted in control, the field's own unit: one cell taken from nothing to
## full Green is 1.0. The result panel turns it into a share of the arena, and a
## cumulative share can pass 100% -- ground that was lost and grown again was grown
## twice.

enum Source {
	CANE,
	SPORE,
	BLOOM,
	BRAMBLE,
	ROOT,
	PRUNING,
	THISTLE,
	VINE,
	FRUIT,
	MAN_EATER,
	RELICS,
	SEEDS,
	OVERGROW,
}

const SOURCE_NAMES := [
	"Cane",
	"Spore",
	"Bloom",
	"Bramble",
	"Root",
	"Pruning",
	"Thistle",
	"Vine",
	"Fruit",
	"Man-Eater",
	"Relics",
	"Seeds",
	"Overgrow",
]

## Seconds into the run, kept current by the run so a contribution can be stamped
## with when it began without every system asking for the clock.
var now := 0.0

var damage := PackedFloat64Array()
var kills := PackedInt32Array()
var green := PackedFloat64Array()
## When each source first dealt damage, or -1 for never. What its DPS is measured
## from, the way Vampire Survivors measures a weapon from when it was picked up
## rather than from the start of the run.
var first_damage_seconds := PackedFloat64Array()

var damage_taken := 0.0
## What Canopy and Bark took off hits that landed.
var damage_prevented := 0.0
var healing := 0.0
## Green the Aftergrowth shield kept from erosion, in control.
var green_shielded := 0.0

## Bramble and Root deal little damage and grow no Green of their own -- they hold
## what the rest of the build does -- so they get stats of their own for the result
## screen, each measured where the effect is decided.
##
## Pixels Bramble's repulsion shoved Grazers off the Green.
var bramble_shove_pixels := 0.0
## Enemy-seconds of walking the slow and the Ensnare took away.
var bramble_movement_denied := 0.0
var bramble_ensnares := 0
## Green the hedge's resistance kept from erosion and hostile growth, in control.
var bramble_green_held := 0.0
## Green Mature Strength kept from erosion and hostile growth, in control.
var root_green_held := 0.0
## Green Root's Regeneration put back, in control.
var root_green_regrown := 0.0
## The most of the arena that was ever Mature at once, in percent.
var peak_mature_percent := 0.0


func _init() -> void:
	reset()


func reset() -> void:
	var count := Source.size()
	damage.resize(count)
	damage.fill(0.0)
	kills.resize(count)
	kills.fill(0)
	green.resize(count)
	green.fill(0.0)
	first_damage_seconds.resize(count)
	first_damage_seconds.fill(-1.0)
	damage_taken = 0.0
	damage_prevented = 0.0
	healing = 0.0
	green_shielded = 0.0
	bramble_shove_pixels = 0.0
	bramble_movement_denied = 0.0
	bramble_ensnares = 0
	bramble_green_held = 0.0
	root_green_held = 0.0
	root_green_regrown = 0.0
	peak_mature_percent = 0.0
	now = 0.0


func record_damage(source: int, amount: float) -> void:
	if not _valid(source) or amount <= 0.0:
		return
	damage[source] += amount
	if first_damage_seconds[source] < 0.0:
		first_damage_seconds[source] = now


func record_kill(source: int) -> void:
	if _valid(source):
		kills[source] += 1


func record_green(source: int, control: float) -> void:
	if _valid(source) and control > 0.0:
		green[source] += control


func get_total_damage() -> float:
	var total := 0.0
	for value in damage:
		total += value
	return total


func get_total_kills() -> int:
	var total := 0
	for value in kills:
		total += value
	return total


## Damage per second since the source first dealt any. A source that joined late is
## not diluted by the minutes before it existed.
func get_dps(source: int) -> float:
	if not _valid(source) or first_damage_seconds[source] < 0.0:
		return 0.0
	return damage[source] / maxf(now - first_damage_seconds[source], 1.0)


## Every source that did anything, largest damage first, then largest Green.
func get_ranked_sources() -> Array[int]:
	var ranked: Array[int] = []
	for source in range(Source.size()):
		if damage[source] > 0.0 or kills[source] > 0 or green[source] > 0.0:
			ranked.append(source)
	ranked.sort_custom(func(a: int, b: int) -> bool:
		if not is_equal_approx(damage[a], damage[b]):
			return damage[a] > damage[b]
		return green[a] > green[b]
	)
	return ranked


func capture_state() -> Dictionary:
	return {
		"now": now,
		"damage": Array(damage),
		"kills": Array(kills),
		"green": Array(green),
		"first_damage_seconds": Array(first_damage_seconds),
		"damage_taken": damage_taken,
		"damage_prevented": damage_prevented,
		"healing": healing,
		"green_shielded": green_shielded,
		"bramble_shove_pixels": bramble_shove_pixels,
		"bramble_movement_denied": bramble_movement_denied,
		"bramble_ensnares": bramble_ensnares,
		"bramble_green_held": bramble_green_held,
		"root_green_held": root_green_held,
		"root_green_regrown": root_green_regrown,
		"peak_mature_percent": peak_mature_percent,
	}


func apply_state(state: Dictionary) -> void:
	reset()
	if state.is_empty():
		return
	now = float(state.get("now", 0.0))
	damage = _restore_floats(damage, state.get("damage", []))
	green = _restore_floats(green, state.get("green", []))
	first_damage_seconds = _restore_floats(
		first_damage_seconds, state.get("first_damage_seconds", [])
	)
	var saved_kills: Variant = state.get("kills", [])
	if saved_kills is Array:
		for index in range(mini(kills.size(), saved_kills.size())):
			kills[index] = int(saved_kills[index])
	damage_taken = float(state.get("damage_taken", 0.0))
	damage_prevented = float(state.get("damage_prevented", 0.0))
	healing = float(state.get("healing", 0.0))
	green_shielded = float(state.get("green_shielded", 0.0))
	bramble_shove_pixels = float(state.get("bramble_shove_pixels", 0.0))
	bramble_movement_denied = float(state.get("bramble_movement_denied", 0.0))
	bramble_ensnares = int(state.get("bramble_ensnares", 0))
	bramble_green_held = float(state.get("bramble_green_held", 0.0))
	root_green_held = float(state.get("root_green_held", 0.0))
	root_green_regrown = float(state.get("root_green_regrown", 0.0))
	peak_mature_percent = float(state.get("peak_mature_percent", 0.0))


static func source_name(source: int) -> String:
	if source < 0 or source >= SOURCE_NAMES.size():
		return ""
	return SOURCE_NAMES[source]


func _valid(source: int) -> bool:
	return source >= 0 and source < Source.size()


## The fresh array with the saved values laid over it, as far as both reach, so a save
## written with fewer sources than this build has still loads.
static func _restore_floats(fresh: PackedFloat64Array, saved: Variant) -> PackedFloat64Array:
	var restored := fresh.duplicate()
	if saved is Array:
		for index in range(mini(restored.size(), saved.size())):
			restored[index] = float(saved[index])
	return restored
