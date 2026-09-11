class_name FruitseedState
extends RefCounted

## What a burst Fruit leaves behind while it germinates.

var active := false
var position := Vector2.ZERO
var remaining := 0.0
var duration := 1.0
var area_multiplier := 1.0
var dropped_seed := false
var fragment := false
var rotation := 0.0
var direction := Vector2.RIGHT
var visual_index := 0
var visual_scale := 1.0
var damage := 0.0
var terminal_damage := 0.0
var knockback := 0.0
var normal_roll_distance := 1.0
var can_raise_sapling := true
