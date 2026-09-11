class_name SaplingState
extends RefCounted

## A raised Sapling and the Green it is waiting on.

var active := false
var position := Vector2.ZERO
## Negative while rooted, positive while waiting for Green to return.
var dormant_remaining := -1.0
## Lets the queued terminal foothold resolve before support is evaluated.
var support_grace_remaining := 0.0
var release_toggle := false
var support_remaining := 0.0
