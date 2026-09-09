class_name EnemyProfiles
extends Node

## The authored enemy roster: one `EnemyProfile` child per archetype the run can
## spawn, each holding that archetype's combat statistics, targeting priority,
## navigation clearance and territory behavior.
##
## It is a container, not a system. `CombatDirector` holds a typed reference to
## each child and copies a profile into an enemy as it spawns, which is why editing
## one changes future spawns and leaves everything already alive alone. Nothing
## here runs per frame, and nothing here may reach into an enemy that is already in
## the arena.
##
## The roster lives in its own scene so enemy tuning is one file to open rather
## than two hundred lines in the middle of the run scene. Add an archetype by
## adding a child here and an exported reference on `CombatDirector`; the child's
## `Role` names the slot it fills.
