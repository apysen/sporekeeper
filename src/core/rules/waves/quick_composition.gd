class_name QuickComposition
extends RefCounted

## Which enemy the next Quick pack is made of.
##
## Quick has no authored wave table - the Campaign's is a model - so its composition is
## a schedule: each specialist has a minute it first appears and a pack cycle it then
## arrives on, and two of them have a late variant that takes over part of their share.
##
## **Nothing here is rolled.** The cycles are counted and the shares are honoured by
## period, so a run cannot be handed eight Siege Corruptors in a row because the dice
## allowed it. That is the difference between a mix and a streak, and it is the reason
## this is a rule with a test rather than a call to `randi`.
##
## The counters stay on the director because they are the run's state and go into its
## save; what moved here is the decision they feed.

## The minute each specialist joins the mix and the pack cycle it then arrives on,
## built from the director's authored values at the moment of the decision - so a
## playtest that edits a cycle in the Inspector is obeyed by the next pack.
class Schedule extends RefCounted:
	var warden_intro_seconds := 0.0
	var warden_pack_cycle := 2
	var colonizer_intro_seconds := 0.0
	var colonizer_pack_cycle := 2
	var corruptor_intro_seconds := 0.0
	var corruptor_pack_cycle := 2
	var saboteur_intro_seconds := 0.0
	var saboteur_pack_cycle := 2
	var siege_corruptor_intro_seconds := 0.0
	var siege_corruptor_share := 0.0


## What was chosen, and the variant counter as it stands afterwards. Returned rather
## than written back, because a rule that reaches into the director to advance a
## counter is a rule that cannot be asked a question without changing the run.
class Selection extends RefCounted:
	var role := 0
	var variant_sequence := 0

	func _init(chosen_role: int, sequence: int) -> void:
		role = chosen_role
		variant_sequence = sequence


## The role for the pack at `pack_sequence`, falling back to whatever the sector
## pressure asked for when no specialist is due.
##
## The order is the priority: Warden, then Colonizer, then Corruptor, then Saboteur.
## Two specialists due on the same pack means the earlier one in that list takes it,
## and the other arrives on its next turn of the cycle.
static func select_role(
	schedule: Schedule,
	elapsed_seconds: float,
	pack_sequence: int,
	variant_sequence: int,
	pressure_role: int
) -> Selection:
	if (
		elapsed_seconds >= schedule.warden_intro_seconds
		and pack_sequence % maxi(2, schedule.warden_pack_cycle) == 0
	):
		return Selection.new(EnemyKinds.Role.WARDEN, variant_sequence)
	if (
		elapsed_seconds >= schedule.colonizer_intro_seconds
		and pack_sequence % maxi(2, schedule.colonizer_pack_cycle) == 0
	):
		return Selection.new(EnemyKinds.Role.COLONIZER, variant_sequence)
	if (
		elapsed_seconds >= schedule.corruptor_intro_seconds
		and pack_sequence % maxi(2, schedule.corruptor_pack_cycle) == 0
	):
		var siege := next_variant(
			elapsed_seconds,
			schedule.siege_corruptor_intro_seconds,
			schedule.siege_corruptor_share,
			variant_sequence
		)
		if bool(siege[0]):
			return Selection.new(EnemyKinds.Role.SIEGE_CORRUPTOR, int(siege[1]))
		return Selection.new(EnemyKinds.Role.CORRUPTOR, int(siege[1]))
	if (
		elapsed_seconds >= schedule.saboteur_intro_seconds
		and pack_sequence % maxi(2, schedule.saboteur_pack_cycle) == 0
	):
		return Selection.new(EnemyKinds.Role.SABOTEUR, variant_sequence)
	return Selection.new(pressure_role, variant_sequence)


## Whether this spawn is the late variant, and the counter afterwards, as
## `[took_variant, variant_sequence]`.
##
## Deterministic rather than rolled: a share of one in three is every third spawn, so
## the proportion is honoured across successive spawns instead of on average over a
## run nobody plays long enough to average out.
static func next_variant(
	elapsed_seconds: float, intro_seconds: float, share: float, variant_sequence: int
) -> Array:
	if elapsed_seconds < intro_seconds or share <= 0.0:
		return [false, variant_sequence]
	if share >= 1.0:
		return [true, variant_sequence]
	var sequence := variant_sequence + 1
	var period := maxi(2, int(round(1.0 / share)))
	return [sequence % period == 0, sequence]
