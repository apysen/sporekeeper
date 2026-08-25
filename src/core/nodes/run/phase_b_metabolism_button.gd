@tool
class_name PhaseBMetabolismButton
extends Button

## One axis in the Ecosystem Development drawer: the button the player presses to
## buy a level, with its own wording and its progress toward the next one.
##
## A Button centres whatever is in its `text` property and gives no way to move it,
## so the wording is drawn by a child `Caption` label instead and the button keeps
## only the press behaviour and the background. Both the caption and the meter are
## placed in the scene, by hand, and this script does not touch their rects — an
## earlier version recomputed them from exported offsets on every run, which
## silently undid anything dragged in the editor.
##
## Runs as a tool script so the wording appears while the drawer is being arranged.

@export_group("Contents")
## The wording, mirrored into the `Caption` child. Set by the run controller during
## play; what is typed here is what the editor shows.
@export_multiline var display_text := "MASS   RANK 1\n[ AUTOMATIC ]   More material":
	set(value):
		if display_text == value:
			return
		display_text = value
		_refresh_caption()


func _ready() -> void:
	_refresh_caption()


func set_display_text(value: String) -> void:
	display_text = value


func get_caption() -> Label:
	return get_node_or_null("Caption") as Label


func get_meter() -> ProgressBar:
	return get_node_or_null("LevelMeter") as ProgressBar


func _refresh_caption() -> void:
	if not is_inside_tree():
		return
	# Nothing is ever left in the Button's own text: it would draw underneath the
	# caption, in a place nothing can move it from.
	text = ""
	var caption := get_caption()
	if caption == null:
		return
	caption.text = display_text
