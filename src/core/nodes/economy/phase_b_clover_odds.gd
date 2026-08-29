class_name PhaseBCloverOdds
extends Node

## Everything the Clover machine knows about chance: the base table per stake, the
## protection that stops a run from being ruined by ordinary bad luck, and the
## construction of the three faces that show the answer.
##
## The result is rolled first and the reels are built to represent it. That is the
## opposite of spinning three independent wheels, and it is deliberate: it is the only
## way the drought protection and the Bust anti-streak can exist at all without the
## displayed symbols quietly lying about what the machine actually does. The reels are
## a reveal, and a reveal is allowed to be theatre as long as the number underneath it
## is the number the interface printed.

@export_group("Collaborators")
## The run this table belongs to. Kept as a collaborator because the machine is scoped
## to a run, not because the table reads relics: Clover deliberately has no relic pool.
@export var progression: PhaseBProgression

@export_group("Base Table")
## Chance of a single Path jackpot, one entry per Stake in enum order. Higher stakes
## buy better odds rather than a bigger prize, because the prize is already a fully
## maxed Path and there is nowhere above that to go.
@export var path_jackpot_chances := PackedFloat32Array([0.095, 0.21, 0.38, 0.55])
## Chance of Triple Clover, which fires every Path at once. Never modified by pity: a
## guaranteed mega jackpot is a scheduled event, and a scheduled event is not a jackpot.
@export var triple_clover_chances := PackedFloat32Array([0.005, 0.01, 0.02, 0.05])
## Chance of Triple Bust, which turns the wagered ground hostile.
@export var triple_bust_chances := PackedFloat32Array([0.005, 0.02, 0.07, 0.15])

@export_group("Drought Protection")
## Spins without a positive result before pity begins, counted per stake.
@export_range(0, 20, 1) var drought_grace_spins := 4
## Extra Path jackpot chance added at 1, 2, 3... spins past the grace, the last entry
## repeating forever. Taken out of Whiff only - never out of Bust, which would make
## losing streaks safer, and never out of Triple Clover.
@export var drought_bonuses := PackedFloat32Array([0.03, 0.06, 0.10, 0.15, 0.22, 0.30])
## Ceiling on total positive chance after pity, per stake. Without it a long Low-stake
## drought would eventually pay better than All In and there would be no reason to ever
## take a real risk.
@export var positive_caps := PackedFloat32Array([0.40, 0.55, 0.60, 0.70])

@export_group("Bust Protection")
## Triple Bust chance multiplier on the first, second and third-onward spin after a
## Bust. Two catastrophes in a row reads as the machine having decided the run is over,
## which is a different feeling from having gambled and lost.
@export var post_bust_multipliers := PackedFloat32Array([0.0, 0.5, 1.0])

@export_group("Display")
## How a Path jackpot is drawn: three of the Path, two plus a Clover, or one plus two
## Clovers. Weights in that order.
@export var path_display_weights := PackedFloat32Array([0.60, 0.30, 0.10])
## Share of whiffs that stop the first two reels on the same face, so the third reel's
## slowdown cannot be read as an announcement that the line has already won.
@export_range(0.0, 1.0, 0.05) var tease_whiff_share := 0.25
## Within a tease: matching Path pair, then Clover/Clover, then Bust/Bust.
@export var tease_kind_weights := PackedFloat32Array([0.70, 0.15, 0.15])

var _drought := PackedInt32Array([0, 0, 0, 0])
var _spins_since_bust := 999
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	reset_odds()


func reset_odds() -> void:
	for stake in range(_drought.size()):
		_drought[stake] = 0
	# Starts clear rather than in cooldown, so the first spin of a run plays the table
	# the interface is showing.
	_spins_since_bust = 999


func set_seed(seed_value: int) -> void:
	## One owned random source, seedable, so a reported spin can be reproduced.
	_rng.seed = seed_value


func get_drought(stake: int) -> int:
	return _drought[clampi(stake, 0, _drought.size() - 1)]


func get_spins_since_bust() -> int:
	return _spins_since_bust


func get_drought_bonus(stake: int) -> float:
	var past_grace := get_drought(stake) - drought_grace_spins
	if past_grace <= 0 or drought_bonuses.is_empty():
		return 0.0
	return drought_bonuses[mini(past_grace, drought_bonuses.size()) - 1]


func get_bust_multiplier() -> float:
	if post_bust_multipliers.is_empty():
		return 1.0
	return post_bust_multipliers[mini(_spins_since_bust, post_bust_multipliers.size() - 1)]


func get_effective_odds(stake: int) -> Dictionary:
	## What this spin would actually pay right now, which is what the HUD prints. The
	## machine is allowed to protect the player from ugly randomness; it is not allowed
	## to advertise one number and roll another. That rule is why anything that changes the
	## odds changes them here, where the readout reads them, rather than quietly at the
	## point of the roll.
	var index := clampi(stake, 0, path_jackpot_chances.size() - 1)
	var clover := triple_clover_chances[index]
	var bust := triple_bust_chances[index] * get_bust_multiplier()
	var cap := positive_caps[index]
	var path := path_jackpot_chances[index] + get_drought_bonus(stake)
	path = clampf(path, 0.0, maxf(0.0, cap - clover))
	return {
		"path_jackpot": path,
		"triple_clover": clover,
		"triple_bust": bust,
		"whiff": maxf(0.0, 1.0 - path - clover - bust),
		"positive": path + clover,
	}


func roll_outcome(stake: int) -> int:
	var odds := get_effective_odds(stake)
	var roll := _rng.randf()
	var clover: float = odds["triple_clover"]
	var path: float = odds["path_jackpot"]
	var bust: float = odds["triple_bust"]
	if roll < clover:
		return CloverSlot.Outcome.TRIPLE_CLOVER
	roll -= clover
	if roll < path:
		return CloverSlot.Outcome.PATH_JACKPOT
	roll -= path
	if roll < bust:
		return CloverSlot.Outcome.TRIPLE_BUST
	return CloverSlot.Outcome.WHIFF


func pick_path() -> int:
	## Uniform across the eight Paths. Pity belongs to the question of whether anything
	## was won; steering which Path arrives would make the machine an upgrade dispenser
	## with a lever on it.
	return CloverSlot.PATH_SYMBOLS[_rng.randi_range(0, CloverSlot.PATH_SYMBOLS.size() - 1)]


func note_outcome(stake: int, outcome: int) -> void:
	# Droughts are counted per stake, so cheap Low spins cannot charge up pity and have
	# it cashed out on an All In.
	var index := clampi(stake, 0, _drought.size() - 1)
	_drought[index] = 0 if CloverSlot.is_positive_outcome(outcome) else _drought[index] + 1
	if outcome == CloverSlot.Outcome.TRIPLE_BUST:
		_spins_since_bust = 0
	else:
		_spins_since_bust = mini(_spins_since_bust + 1, 999)


func build_display(outcome: int, path_symbol: int) -> PackedInt32Array:
	## The three faces that will be shown for an already-decided result.
	match outcome:
		CloverSlot.Outcome.TRIPLE_CLOVER:
			return PackedInt32Array([
				CloverSlot.Symbol.CLOVER,
				CloverSlot.Symbol.CLOVER,
				CloverSlot.Symbol.CLOVER,
			])
		CloverSlot.Outcome.TRIPLE_BUST:
			return PackedInt32Array([
				CloverSlot.Symbol.BUST,
				CloverSlot.Symbol.BUST,
				CloverSlot.Symbol.BUST,
			])
		CloverSlot.Outcome.PATH_JACKPOT:
			return _build_path_display(path_symbol)
		_:
			return _build_whiff_display()


func _build_path_display(path_symbol: int) -> PackedInt32Array:
	var clovers := _weighted_pick(path_display_weights)
	var faces := PackedInt32Array([path_symbol, path_symbol, path_symbol])
	var positions := [0, 1, 2]
	for _step in range(clovers):
		var slot: int = positions.pop_at(_rng.randi_range(0, positions.size() - 1))
		faces[slot] = CloverSlot.Symbol.CLOVER
	return faces


func _build_whiff_display() -> PackedInt32Array:
	if _rng.randf() < tease_whiff_share:
		var tease := _build_tease_display()
		if CloverSlot.resolve_outcome(tease) == CloverSlot.Outcome.WHIFF:
			return tease
	# Rejection rather than construction. Building a guaranteed non-winning line by hand
	# means encoding the winning grammar a second time, and a second copy of a rule is a
	# copy that will eventually disagree with the first.
	for _attempt in range(64):
		var faces := PackedInt32Array([_any_symbol(), _any_symbol(), _any_symbol()])
		if faces[0] == faces[1]:
			continue
		if CloverSlot.resolve_outcome(faces) == CloverSlot.Outcome.WHIFF:
			return faces
	return PackedInt32Array([
		CloverSlot.Symbol.ROOT,
		CloverSlot.Symbol.BLOOM,
		CloverSlot.Symbol.BUST,
	])


func _build_tease_display() -> PackedInt32Array:
	match _weighted_pick(tease_kind_weights):
		0:
			var path: int = CloverSlot.PATH_SYMBOLS[
				_rng.randi_range(0, CloverSlot.PATH_SYMBOLS.size() - 1)
			]
			var third := path
			while third == path or third == CloverSlot.Symbol.CLOVER:
				third = _any_symbol()
			return PackedInt32Array([path, path, third])
		1:
			# Clover / Clover / Bust. The wild cannot finish a Bust, so the line that
			# looks like the best possible position is worth nothing.
			return PackedInt32Array([
				CloverSlot.Symbol.CLOVER,
				CloverSlot.Symbol.CLOVER,
				CloverSlot.Symbol.BUST,
			])
		_:
			var survivor := _any_symbol()
			while survivor == CloverSlot.Symbol.BUST:
				survivor = _any_symbol()
			return PackedInt32Array([
				CloverSlot.Symbol.BUST,
				CloverSlot.Symbol.BUST,
				survivor,
			])


func _any_symbol() -> int:
	return _rng.randi_range(0, CloverSlot.Symbol.size() - 1)


func _weighted_pick(weights: PackedFloat32Array) -> int:
	var total := 0.0
	for weight in weights:
		total += maxf(0.0, weight)
	if total <= 0.0:
		return 0
	var pick := _rng.randf() * total
	for index in range(weights.size()):
		pick -= maxf(0.0, weights[index])
		if pick <= 0.0:
			return index
	return weights.size() - 1
