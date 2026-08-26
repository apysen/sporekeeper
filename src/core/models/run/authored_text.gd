class_name AuthoredText
extends RefCounted

## The wording a scene author typed, kept as the template the game renders from.
##
## Every dynamic line in the interface used to be a format string living in code, so
## the text typed into a Label in the editor was overwritten on the first frame and
## the editor lied about what the game said. This inverts that: the authored text is
## captured once, before anything writes to the control, and every later update is a
## render of that same text with the run's numbers substituted in.
##
## Templates use named placeholders - `HEALTH  {current} / {maximum}` - rather than
## positional `%d`, because a name survives being moved, and a placeholder the author
## deletes simply stops appearing instead of shifting every value after it onto the
## wrong slot. A placeholder that matches nothing is left in the text exactly as
## typed, which is what makes a misspelt name visible rather than silent.
##
## Controls are addressed by instance and property, so the same bank holds a Label's
## `text`, a Button's `tooltip_text`, and an axis button's `display_text`.

## Authored values, keyed by instance id and property name. Ids rather than the
## controls themselves so a freed control cannot keep its template alive.
var _templates: Dictionary = {}


## Records what each control says now, to be used as its template from here on.
## Safe to call with nulls and with controls that carry no such property.
func capture(controls: Array, property := "text") -> void:
	for control: Object in controls:
		capture_one(control, property)


func capture_one(control: Object, property := "text") -> void:
	if control == null or not is_instance_valid(control):
		return
	var key := _key(control, property)
	if _templates.has(key):
		# Captured already: re-reading would take whatever the game last wrote and
		# promote it to the template, which is the bug this class exists to remove.
		return
	var value: Variant = control.get(property)
	_templates[key] = "" if value == null else String(value)


## The authored template for a control, or `fallback` when the author left it blank
## or the control is missing from the scene. A blank field means "say the usual
## thing" rather than "say nothing", so a half-filled scene still reads correctly.
func template(control: Object, fallback := "", property := "text") -> String:
	if control == null or not is_instance_valid(control):
		return fallback
	var authored: String = _templates.get(_key(control, property), "")
	return fallback if authored.is_empty() else authored


## Substitutes `values` into a template. Placeholders with no matching key are left
## as typed.
static func render(text: String, values: Dictionary) -> String:
	if values.is_empty():
		return text
	return text.format(values)


## Renders a control's own authored text back into it.
func write(control: Object, values: Dictionary = {}, fallback := "", property := "text") -> void:
	if control == null or not is_instance_valid(control):
		return
	control.set(property, render(template(control, fallback, property), values))


## Renders an alternate template - a state the control does not sit in at rest, such
## as a countdown or an unavailable readout - into the control. The alternates are
## exported strings on the owning script, so they are edited in the Inspector the way
## the resting wording is edited on the node itself.
func write_variant(
	control: Object,
	variant: String,
	values: Dictionary = {},
	property := "text"
) -> void:
	if control == null or not is_instance_valid(control):
		return
	control.set(property, render(variant, values))


## Replaces a captured template. The editor is the normal way wording changes;
## this is how a test re-authors a line the way a designer would retype it, and
## how anything that swaps wording at runtime does it without touching the control.
func set_template(control: Object, text: String, property := "text") -> void:
	if control == null or not is_instance_valid(control):
		return
	_templates[_key(control, property)] = text


static func _key(control: Object, property: String) -> String:
	return "%d:%s" % [control.get_instance_id(), property]
