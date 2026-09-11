class_name FruitState
extends RefCounted

## One Fruit rolling, and every budget a relic may spend on it before it bursts.

var active := false
var dropped_seed := false
var fragment := false
var position := Vector2.ZERO
var velocity := Vector2.ZERO
var speed := 0.0
var base_speed := 0.0
var deceleration := 0.0
## Seconds this Fruit may keep rolling before it bursts wherever it is. A Fruit
## is a roll and then a burst; nothing legitimately outlives its own roll, so
## this is the backstop that makes permanent scenery impossible.
var roll_deadline_remaining := 0.0
var last_direction := Vector2.RIGHT
var remaining_distance := 0.0
var maximum_distance := 1.0
var normal_roll_distance := 1.0
var damage := 0.0
var terminal_damage := 0.0
var knockback := 0.0
## Trail and terminal area are separate because GRAFT's Prize Fruit enlarges
## only the terminal foothold, while Germination/Fertile Union affect both.
var germination_multiplier := 1.0
var terminal_germination_multiplier := 1.0
var visual_scale := 1.0
var visual_index := 0
var rotation := 0.0
var trail_debt := 0.0
var hit_cooldowns := {}
var first_enemy_collision := true
var thick_rind_available := false
var first_obstacle_bounce := true
var bank_shot_armed := false
var first_collision_damage_multiplier := 1.0
var carried_thistle_remaining := 0.0
var burdock_reset_remaining := 0.0
var graft_cuttings := 0
var prize := false
var can_raise_sapling := true
## Which release threw this Fruit, and which Fruit of that release it is. Fruit
## Salad needs both: two hits from the same Fruit are not two Fruit.
var release_id := 0
var fruit_id := 0
## Stem Steering and Windfall each redirect the same Fruit, so each keeps its own
## budget rather than sharing one and quietly stealing from the other.
var steering_uses := 0
var windfall_uses := 0
var windfall_cooldown := 0.0
## Bruised Fruit is measured in travel rather than time, so a Fruit that has
## nearly stopped does not keep painting wide.
var juicy_remaining := 0.0
## Newton's Apple chain starters this Fruit has spent, and the clock between them.
var newton_starters := 0
var newton_cooldown := 0.0
