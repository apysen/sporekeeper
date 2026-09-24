class_name ChoicePanel
extends Panel

## The draft: a heading, up to four cards, and a reroll.
##
## It knows nothing about upgrades, relics or Evolutions. It is handed already
## composed text and a tint per card and reports which card was pressed, because
## what a card *says* is built from progression and the path directors, and that
## knowledge belongs with them rather than in the control that draws it. That is
## what makes this the same panel for an upgrade draft, a relic reward and a
## milestone Adaptation offer.

## A card was pressed. The index is into the options last shown.
signal option_chosen(index: int)
## The reroll was pressed. Whether there is anything to reroll is the run's business;
## this only reports the press.
signal reroll_requested
## The pointer entered a visible card. Carries the button so the tooltip stack can
## anchor to it.
signal option_hovered(index: int, button: Button)

@export var header: Label
@export var button_one: Button
@export var button_two: Button
@export var button_three: Button
@export var button_four: Button
@export var reroll_button: Button

## The four cards in order. The index into this array is the index reported by
## `option_chosen`, and it is the same index the caller passed options in.
var buttons: Array[Button] = []

var _authored := AuthoredText.new()


func _ready() -> void:
	buttons = [button_one, button_two, button_three, button_four]
	# Only the reroll carries an authored template; the cards are given their whole
	# text by the caller, so capturing them would preserve wording nothing reads.
	_authored.capture([reroll_button])
	_authored.capture([reroll_button], "tooltip_text")
	for index in range(buttons.size()):
		var button := buttons[index]
		if button == null:
			continue
		button.pressed.connect(_on_button_pressed.bind(index))
		button.mouse_entered.connect(_on_button_hovered.bind(index))
	reroll_button.pressed.connect(_on_reroll_pressed)
	visible = false


## Shows the panel with one card per entry. Each entry is `{"text": String}` and may
## carry `"modulate": Color`; anything past the fourth entry is not shown, and any
## card without an entry is hidden rather than left holding the last draft's wording.
func show_options(header_text: String, entries: Array, queued: int = 0) -> void:
	## `queued` is how many more panels are waiting behind this one.
	##
	## A wave boundary can owe a draft, a relic, an Evolution and a Growth at once, and
	## an unlimited Provocation can owe several Growths on top -- so a player answering
	## one panel had no way to know whether they were finishing or a third of the way
	## through. The count goes on the heading rather than beside it because the heading
	## is the one thing on the panel they are already reading.
	header.text = (
		"%s   %d OF %d" % [header_text, 1, queued + 1] if queued > 0 else header_text
	)
	for index in range(buttons.size()):
		var button := buttons[index]
		if button == null:
			continue
		if index >= entries.size():
			button.visible = false
			continue
		var entry: Dictionary = entries[index]
		button.visible = true
		button.text = String(entry.get("text", ""))
		button.modulate = entry.get("modulate", Color.WHITE)
		# Reward explanations are rendered by MechanicsHelp. Leaving the native
		# tooltip empty prevents a delayed duplicate appearing over the styled cards.
		button.tooltip_text = ""
	visible = true


func hide_options() -> void:
	visible = false


## `rerolls_left` fills the authored wording on the button; `can_reroll` is false when
## the offer presents every option there is and so cannot be redrawn.
func set_reroll_state(can_reroll: bool, rerolls_left: int) -> void:
	if not is_instance_valid(reroll_button):
		return
	reroll_button.visible = can_reroll
	reroll_button.disabled = rerolls_left <= 0
	_authored.write(reroll_button, {"left": rerolls_left})


func _on_button_pressed(index: int) -> void:
	option_chosen.emit(index)


func _on_button_hovered(index: int) -> void:
	var button := buttons[index]
	if button == null or not button.visible:
		return
	option_hovered.emit(index, button)


func _on_reroll_pressed() -> void:
	reroll_requested.emit()
