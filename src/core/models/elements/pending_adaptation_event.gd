class_name PendingAdaptationEvent
extends RefCounted

## One Adaptation effect scheduled to resolve after a delay.
##
## Named for what it is rather than kept as `PendingEvent`: as a project-wide class
## that name says nothing about which system owns it. `Kind` moved in with it - the
## enum has no reader but this struct.

enum Kind {
	THISTLE_VOLLEY,
	CANE_SWEEP,
	THORNWHIP_SECOND_HALF,
	WISTERIA_SEQUENCE,
	WISTERIA_BLOSSOM,
	ESPALIER_CUTTINGS,
}

var active := false
var kind := Kind.THISTLE_VOLLEY
var remaining := 0.0
var origin := Vector2.ZERO
var facing := Vector2.RIGHT
var left_to_right := true
var damage_scale := 1.0
var count := 0
var extra_pierce := 0
var reach := 0.0
