class_name RootedGlowState
extends RefCounted

## One point's reading of the Root Network under it: whether it is standing on
## Mature player ground, how deep the Network is there, and how much of the
## transition flare is left. Kept per point rather than recomputed in _draw so a
## paused run holds its light still instead of breathing on a stopped clock.

var lit := false
var network := 1.0
var flare := 0.0
var _was_lit := false


func advance(
	delta: float,
	now_lit: bool,
	now_network: float,
	flare_seconds: float
) -> void:
	# Both edges flare. Stepping on is when the whole unit is won and stepping
	# off is when it is lost, and the second is the one a player misses.
	if now_lit != _was_lit:
		flare = 1.0
	elif flare > 0.0:
		flare = maxf(0.0, flare - delta / maxf(0.01, flare_seconds))
	_was_lit = now_lit
	lit = now_lit
	network = now_network


func clear() -> void:
	lit = false
	network = 1.0
	flare = 0.0
	_was_lit = false
