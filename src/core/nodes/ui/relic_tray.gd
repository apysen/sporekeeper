class_name RelicTray
extends Panel

## The relic row: a fixed heading and the rounded slots showing what the run holds.
##
## Relics are taken, never ranked, so this row is a collection rather than a tree.
## It shows exactly what the run holds, in the order it was taken, plus one empty
## socket to say more are coming - a permanent row of placeholders would promise
## slots for relics the run may never be offered.
##
## It owns the row and how it draws. It does not own the tooltip stack: the same
## stack serves reward and Adaptation hovers elsewhere, so a hover here is reported
## and the run root decides what to show. Nor does it own the wave cadence the empty
## socket names - that is the run's own authored tuning, handed over in `setup`.

## The pointer entered a slot. Carries the wording and the rect to anchor to.
signal slot_hovered(title: String, body: String, anchor: Rect2)

## The fixed word above the row. The Paths the run has taken are read from the
## slots beneath it, never from this line.
@onready var heading_label: Label = %RelicsLabel
@onready var slots: UpgradeSlots = %RelicSlots

var _authored := AuthoredText.new()
var _progression: Progression
var _relic_director: RelicDirector
## The authored row length is the ceiling the run grows toward, so it is read once
## here, before `refresh` first trims the row to what the run currently holds.
var _maximum_slots := 6
var _reward_wave_cycle := 0


func _ready() -> void:
	_authored.capture([heading_label, slots])
	_authored.capture([heading_label, slots], "tooltip_text")
	_maximum_slots = slots.slot_count
	slots.slot_hovered.connect(_on_slot_hovered)


## Hands over what the row reads. The run root calls this from its own `_ready`,
## which is after this node's. `reward_wave_cycle` is the run's authored cadence,
## so the empty socket names where the next relic comes from rather than writing
## that number a second time.
func setup(
	progression: Progression, relic_director: RelicDirector, reward_wave_cycle: int
) -> void:
	_progression = progression
	_relic_director = relic_director
	_reward_wave_cycle = reward_wave_cycle


func refresh() -> void:
	if _progression == null:
		return
	# The pool is far larger than the row, so the row shows what the run actually
	# holds, in the order it was taken, with the trigger counter a relic needs to
	# be readable on the slot itself.
	var held := PackedInt32Array()
	for relic_id in range(RelicCatalog.get_count()):
		if _progression.has_relic(relic_id):
			held.append(relic_id)
	# One empty socket beyond what the run holds: enough to say more are coming,
	# without a permanent row of placeholders for relics it may never take.
	slots.slot_count = clampi(held.size() + 1, 1, _maximum_slots)
	# The empty slot names where the next relic comes from, so the authored wave
	# cadence is what the tooltip reports rather than a number written twice.
	var empty_hint := "Empty relic slot.\nDefeat an elite or the boss to choose a relic."
	if _reward_wave_cycle > 0:
		empty_hint = (
			"Empty relic slot.\nEvery %d waves, the elite, and the boss each offer one."
			% _reward_wave_cycle
		)
	for index in range(slots.get_slot_count()):
		if index >= held.size():
			slots.set_slot(
				index,
				slots.empty_marker,
				"",
				empty_hint,
				UpgradeSlots.SlotState.EMPTY
			)
			continue
		var relic_id := held[index]
		var relic_name := Progression.get_relic_name(relic_id)
		var rarity := RelicCatalog.get_rarity(relic_id)
		var tooltip := "%s   %s\n%s" % [
			relic_name,
			RelicCatalog.get_rarity_name(rarity),
			_progression.get_relic_description(relic_id),
		]
		var counter := _relic_director.get_relic_counter_text(relic_id)
		if not counter.is_empty():
			tooltip += "\nProgress: %s" % counter
		slots.set_slot(
			index,
			UpgradeDescriptions.initials(relic_name),
			counter,
			tooltip,
			UpgradeSlots.SlotState.FILLED,
			# Rarity on the slot itself, so the row reads as a collection at a glance
			# rather than only under the pointer. Colour is never the only signal: the
			# tooltip still names the rarity in words, which is the same rule the reel
			# faces and the Bust symbol follow.
			RelicCatalog.get_rarity_color(rarity)
		)


func _on_slot_hovered(index: int) -> void:
	var description := slots.get_slot_tooltip(index)
	if description.is_empty():
		return
	var title := description.get_slice("\n", 0).strip_edges()
	# Reported rather than shown: the tooltip stack is shared with reward hovers
	# that have nothing to do with this row, so the run root owns it.
	slot_hovered.emit(
		title, MechanicsHelp.tooltip_body(description, title), slots.get_slot_global_rect(index)
	)
