class_name EnemyRoleScalingProfile
extends Resource

## How much of a wave's global scaling one enemy role actually receives.
##
## Movement speed and action speed are the two most sensitive pressure variables in
## the Campaign, and neither should reach every role equally: a Rusher that gains
## the whole movement curve outruns the reaction window the role is built around,
## and a Grazer whose bite cadence accelerates stops being a grazing burst. The
## exceptions are authored here rather than scattered as wave-number checks through
## the enemy scripts.

@export_group("Identity")
## Role id from CombatDirector.EnemyRole this profile scales.
@export_range(0, 15, 1) var role_id := 0

@export_group("Scaling Shares")
## Share of the wave's movement bonus this role receives. At 0 it never speeds up.
@export_range(0.0, 2.0, 0.01) var movement_scaling_factor := 1.0
## Share of the wave's territory-action-speed bonus this role receives.
@export_range(0.0, 2.0, 0.01) var action_speed_scaling_factor := 1.0
## Whether the wave's global crowd-control resistance applies to this role at all.
@export var receives_global_cc_resistance := true
## Extra role-specific crowd-control resistance applied before the global curve.
## Elites and the Boss may resist more, but must remain visibly affectable.
@export_range(0.0, 0.9, 0.01) var role_cc_resistance := 0.0
## First Campaign wave at which this role may be assigned a random modifier.
## The default keeps a role out of the modifier system entirely.
@export_range(1, 999, 1) var modifier_eligible_from_wave := 999

@export_group("Action Timing")
## Whether the repeated territory-action interval scales at all for this role.
@export var scales_action_interval := true
## Grazing roles keep their authored bite cadence and scale only the rest between
## bursts, so faster waves produce more frequent bursts rather than a faster tick.
@export var scales_rest_interval_only := false
