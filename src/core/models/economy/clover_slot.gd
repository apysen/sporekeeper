class_name CloverSlot
extends RefCounted

## The Clover machine's vocabulary and its winning grammar, with no run state and no
## scene attached. The machine, the odds controller, the HUD and the tests all read the
## same rules from here, which is the only way a slot machine stays honest: the thing
## that decides whether a line paid cannot be a different piece of code from the thing
## that drew it.

## Five Paths, the Clover wild, and the Bust. The five Path faces are the Plant Paths
## themselves rather than an abstract prize table, because the payout is the Path event
## landing on the battlefield.
enum Symbol {
	ROOT,
	SPORE,
	BLOOM,
	BRAMBLE,
	PRUNING,
	CLOVER,
	BUST,
}

## How much of the currently owned organism goes on the table. The notch is not a bet
## size in a currency; it is a share of the living thing, chosen at the instant the
## lever goes down.
enum Stake {
	LOW,
	MEDIUM,
	HIGH,
	ALL_IN,
}

## There are no consolation prizes. A spin either unleashes a Path, unleashes all of
## them, wounds the organism, or does nothing at all.
enum Outcome {
	WHIFF,
	PATH_JACKPOT,
	TRIPLE_CLOVER,
	TRIPLE_BUST,
}

const PATH_SYMBOLS := [
	Symbol.ROOT,
	Symbol.SPORE,
	Symbol.BLOOM,
	Symbol.BRAMBLE,
	Symbol.PRUNING,
]

const STAKE_FRACTIONS := [0.10, 0.25, 0.50, 1.00]


static func get_stake_fraction(stake: int) -> float:
	return STAKE_FRACTIONS[clampi(stake, 0, STAKE_FRACTIONS.size() - 1)]


static func is_path_symbol(symbol: int) -> bool:
	return symbol >= Symbol.ROOT and symbol <= Symbol.PRUNING


static func resolve_path(symbols: PackedInt32Array) -> int:
	## Which Path a line pays, or -1. Clover stands in for a missing Path symbol and
	## for nothing else: it never completes a Bust, and it never picks between two
	## different Paths, so `Bloom / Root / Clover` has no pair to finish and pays
	## nothing. Clover always reads as good news or as nothing, never as the symbol
	## that ruined the line.
	if symbols.size() != 3:
		return -1
	var path := -1
	for symbol in symbols:
		if symbol == Symbol.CLOVER:
			continue
		if not is_path_symbol(symbol):
			return -1
		if path == -1:
			path = symbol
		elif path != symbol:
			return -1
	return path


static func resolve_outcome(symbols: PackedInt32Array) -> int:
	if symbols.size() != 3:
		return Outcome.WHIFF
	var clovers := 0
	var busts := 0
	for symbol in symbols:
		if symbol == Symbol.CLOVER:
			clovers += 1
		elif symbol == Symbol.BUST:
			busts += 1
	if clovers >= 3:
		return Outcome.TRIPLE_CLOVER
	if busts >= 3:
		return Outcome.TRIPLE_BUST
	return Outcome.PATH_JACKPOT if resolve_path(symbols) != -1 else Outcome.WHIFF


static func is_positive_outcome(outcome: int) -> bool:
	return outcome == Outcome.PATH_JACKPOT or outcome == Outcome.TRIPLE_CLOVER


static func get_symbol_name(symbol: int) -> String:
	match symbol:
		Symbol.ROOT:
			return "Root"
		Symbol.SPORE:
			return "Spore"
		Symbol.BLOOM:
			return "Bloom"
		Symbol.BRAMBLE:
			return "Bramble"
		Symbol.PRUNING:
			return "Pruning"
		Symbol.CLOVER:
			return "Clover"
		_:
			return "Bust"


static func get_stake_name(stake: int) -> String:
	match stake:
		Stake.LOW:
			return "Low"
		Stake.MEDIUM:
			return "Medium"
		Stake.HIGH:
			return "High"
		_:
			return "All In"


static func get_outcome_name(outcome: int) -> String:
	match outcome:
		Outcome.PATH_JACKPOT:
			return "JACKPOT"
		Outcome.TRIPLE_CLOVER:
			return "CLOVER JACKPOT"
		Outcome.TRIPLE_BUST:
			return "TRIPLE BUST"
		_:
			return "No win"
