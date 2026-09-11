class_name ThistleState
extends RefCounted

## One Thistle turret: when it fires next, how long it has left, and whether it is
## in the ground or riding on Grandma.

var active := false
var permanent := true
var position := Vector2.ZERO
var attack_remaining := 0.0
var temporary_remaining := 0.0
var unsupported_remaining := -1.0
var collapse_volley_fired := false
var firing_cycles := 0
var heavy_thorns := 0
var bloom_charge_remaining := 0.0
var sequence := 0
var burdock_temporary := false
## A real thistle catches on whatever walks through it. While carried the turret
## rides Grandma, keeps firing from her position, and answers to no supporting
## Green: it is on her coat, not in the ground.
var carried := false
var carry_remaining := 0.0
## Time before this turret is willing to catch on Grandma again. Without it she
## would simply stand on the thing and never put it down.
var stick_cooldown_remaining := 0.0
## The Root Network under this turret, which is where Clustering and Burr are
## measured. A carried turret takes no light of its own: it is standing exactly
## where Grandma is and her own light already says so.
var rooted_glow := RootedGlowState.new()
