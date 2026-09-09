class_name AdaptationTree
extends Control

## The Adaptation panel: two Core rows, the Evolution that joins them, and two
## Branch rows, each showing its four lines as rank pips.
##
## Every owned Adaptation shows all four of its lines, so the panel reads as what
## the run has grown rather than as a list of slots it has consumed. An empty pip
## is a line not bought yet, never one the player can no longer reach.
##
## It owns the rows and how they draw. It does not own what a pip *says* - that is
## `UpgradeDescriptions`, which both this and the run root hold, so neither has to
## reach through the other for a string. Nor does it own the tooltip stack: the same
## stack serves reward and HUD hovers elsewhere, so a hover here is reported and the
## run root decides what to show.

## The pointer entered a filled slot. Carries the wording and the rect to anchor to.
signal slot_hovered(title: String, body: String, anchor: Rect2)

const ADAPTATION_ICON_SPORE := preload("res://assets/art/adaptation_icons/spore/spore.png")
const ADAPTATION_ICON_BLOOM := preload("res://assets/art/adaptation_icons/bloom/bloom_512x512.png")
const ADAPTATION_ICON_BRAMBLE := preload("res://assets/art/adaptation_icons/bramble/bramble.png")
const ADAPTATION_ICON_ROOT := preload("res://assets/art/adaptation_icons/root/root.png")
const ADAPTATION_ICON_PRUNING := preload("res://assets/art/adaptation_icons/pruning/pruning.png")
const ADAPTATION_ICON_THISTLE := preload("res://assets/art/adaptation_icons/thistle/thistle.svg")
const ADAPTATION_ICON_VINE := preload("res://assets/art/adaptation_icons/vine/vine.png")
const ADAPTATION_ICON_FRUIT := preload("res://assets/art/adaptation_icons/fruit/red-apple.png")

@onready var core_one_slots: UpgradeSlots = %Path1Slots
@onready var core_two_slots: UpgradeSlots = %Path2Slots
@onready var evolution_slot: UpgradeSlots = %EvolutionSlot
@onready var branch_one_slots: UpgradeSlots = %SupportSlots
@onready var branch_two_slots: UpgradeSlots = %Branch2Slots
@onready var core_one_label: Label = %Path1Label
@onready var core_two_label: Label = %Path2Label
@onready var branch_one_label: Label = %SupportPathLabel
@onready var branch_two_label: Label = %Branch2Label
@onready var evolution_label: Label = %EvolutionTreeLabel
@onready var core_one_emblem: Label = %Path1EmblemLabel
@onready var core_two_emblem: Label = %Path2EmblemLabel
@onready var branch_one_emblem: Label = %SupportEmblemLabel
@onready var branch_two_emblem: Label = %Branch2EmblemLabel
@onready var core_one_emblem_icon: TextureRect = %Path1EmblemIcon
@onready var core_two_emblem_icon: TextureRect = %Path2EmblemIcon
@onready var branch_one_emblem_icon: TextureRect = %SupportEmblemIcon
@onready var branch_two_emblem_icon: TextureRect = %Branch2EmblemIcon
@onready var branch_one_emblem_lock: TextureRect = %SupportEmblemLock
@onready var branch_two_emblem_lock: TextureRect = %Branch2EmblemLock
## The "ADAPTATIONS" heading, which the Clover cabinet sits on top of in Quick runs.
@onready var heading_label: Label = %Slots

var _authored := AuthoredText.new()
var _progression: Progression
var _descriptions: UpgradeDescriptions


func _ready() -> void:
	_authored.capture([heading_label])
	for row: UpgradeSlots in [
		core_one_slots,
		core_two_slots,
		evolution_slot,
		branch_one_slots,
		branch_two_slots,
	]:
		if row == null:
			continue
		row.slot_hovered.connect(_on_slot_hovered.bind(row))


## Hands over the two things the panel reads. The run root calls this from its own
## `_ready`, which is after this node's.
func setup(progression: Progression, descriptions: UpgradeDescriptions) -> void:
	_progression = progression
	_descriptions = descriptions


## Whether the "ADAPTATIONS" heading is shown. Quick hides it because the Clover
## cabinet sits over it; the rows beneath are self-describing without it.
func set_heading_visible(shown: bool) -> void:
	if heading_label != null:
		heading_label.visible = shown


func refresh() -> void:
	# Ranks bought against ranks the roster can hold, which is what the rows beneath
	# the heading are a picture of.
	_authored.write(heading_label, {
		"filled": _owned_ordinary_rank_total(),
		"total": (
			_progression.get_owned_adaptation_count()
			* Progression.LINES_PER_ADAPTATION
			* _progression.maximum_upgrade_level
		),
	})
	## Five rows: two Cores, the Evolution that joins them, then two Branches.
	##
	## Every owned Adaptation shows all four of its lines with their rank pips, so
	## the panel reads as what the run has grown rather than as a list of slots it
	## has consumed. Nothing is ever locked out here now: an empty pip is a line the
	## player has not bought yet, never one they can no longer reach.
	if core_one_slots == null:
		return
	_update_path_upgrade_row(
		core_one_slots,
		core_one_label,
		core_one_emblem,
		core_one_emblem_icon,
		_progression.primary_path,
		"CORE 1"
	)
	_update_path_upgrade_row(
		core_two_slots,
		core_two_label,
		core_two_emblem,
		core_two_emblem_icon,
		_progression.secondary_path,
		"CORE 2"
	)
	_update_evolution_tree_slot()
	_update_branch_upgrade_row(
		branch_one_slots,
		branch_one_label,
		branch_one_emblem,
		branch_one_emblem_icon,
		branch_one_emblem_lock,
		0,
		"BRANCH 1"
	)
	if branch_two_slots != null:
		_update_branch_upgrade_row(
			branch_two_slots,
			branch_two_label,
			branch_two_emblem,
			branch_two_emblem_icon,
			branch_two_emblem_lock,
			1,
			"BRANCH 2"
		)


func _update_branch_upgrade_row(
	row: UpgradeSlots,
	path_label: Label,
	emblem: Label,
	emblem_icon: TextureRect,
	emblem_lock: TextureRect,
	branch_index: int,
	fallback_label: String
) -> void:
	# A Branch slot the run has not reached yet shows a lock and says what unlocks
	# it, so the roster's shape is legible from the first minute.
	var owned := branch_index < _progression.branch_adaptations.size()
	var path_id := (
		_progression.branch_adaptations[branch_index]
		if owned
		else Progression.UNSELECTED_PATH
	)
	if emblem_lock != null:
		emblem_lock.visible = not owned
	_update_path_upgrade_row(
		row,
		path_label,
		emblem,
		emblem_icon,
		path_id,
		fallback_label
	)
	if not owned:
		emblem.visible = false
		emblem_icon.visible = false
		for index in range(row.get_slot_count()):
			_set_locked_tree_slot(
				row,
				index,
				(
					"Branch Adaptation %d.\nDefeat the %s to choose it."
					% [
						branch_index + 1,
						"Elite Rootbreaker" if branch_index == 0 else "Burrower Boss",
					]
				)
			)


func _update_path_upgrade_row(
	row: UpgradeSlots,
	path_label: Label,
	emblem: Label,
	emblem_icon: TextureRect,
	path_id: int,
	fallback_label: String
) -> void:
	row.slot_count = 4
	var selected := path_id != Progression.UNSELECTED_PATH
	path_label.text = (
		Progression.get_path_name(path_id).to_upper()
		if selected
		else fallback_label
	)
	var accent := _get_path_hud_color(path_id) if selected else Color("596052")
	if selected and _progression.is_adaptation_mastered(path_id):
		# The mastered row is brightened rather than given permanent extra space:
		# mastery is completion, and completion should read at a glance without the
		# panel growing a new element the moment it happens.
		accent = accent.lightened(0.28)
	_set_path_emblem(emblem, emblem_icon, path_id, selected, accent)
	var path_upgrades := _get_path_upgrade_ids(path_id) if selected else PackedInt32Array()
	for index in range(4):
		if not selected or index >= path_upgrades.size():
			_set_locked_tree_slot(
				row,
				index,
				"Acquire this Adaptation to reveal its upgrade lines."
			)
			continue
		var upgrade_id := path_upgrades[index]
		var level := _progression.get_owned_upgrade_level(upgrade_id)
		var maximum := _progression.get_upgrade_maximum_level(upgrade_id)
		if level > 0:
			row.set_slot(
				index,
				_descriptions.abbreviation(upgrade_id),
				# Rank against its own ceiling, so a line at 2 of 3 is never mistaken
				# for a line at 2 of 5 the run has barely started.
				"%d/%d" % [level, maximum],
				_descriptions.tooltip(upgrade_id),
				UpgradeSlots.SlotState.FILLED,
				accent
			)
		else:
			# Every line of an owned Adaptation is always available. There is no
			# locked ordinary line any more, so this row never shows one.
			# No rank line on an unbought slot: the marker is centred in the slot on
			# its own, and a second line under it would push the marker off centre.
			# The ceiling is named in the tooltip instead.
			row.set_slot(
				index,
				row.empty_marker,
				"",
				"%s\nAvailable on an upgrade draft. Reaches rank %d." % [
					Progression.get_upgrade_name(upgrade_id),
					maximum,
				],
				UpgradeSlots.SlotState.EMPTY,
				accent
			)


func _update_evolution_tree_slot() -> void:
	evolution_slot.slot_count = 1
	match _progression.evolution_status:
		Progression.EvolutionStatus.EVOLVED:
			var evolution_name := Evolutions.get_evolution_name(_progression.active_evolution)
			var upgrade_id := Evolutions.get_evolution_upgrade_id(_progression.active_evolution)
			evolution_label.text = evolution_name
			evolution_slot.set_slot(
				0,
				UpgradeDescriptions.initials(evolution_name),
				# Against its own five-rank ceiling, the same way every ordinary line
				# now reads against three.
				"%d/%d" % [
					_progression.get_evolution_upgrade_level(),
					_progression.get_upgrade_maximum_level(upgrade_id),
				],
				_descriptions.tooltip(upgrade_id),
				UpgradeSlots.SlotState.FILLED,
				Color("d4a94f")
			)
		Progression.EvolutionStatus.READY:
			# Named only once it has been claimed. Until then the slot says what it
			# is for and nothing about what is waiting in it.
			evolution_label.text = "EVOLUTION"
			evolution_slot.set_slot(
				0,
				evolution_slot.empty_marker,
				"",
				"This pairing has not evolved yet.",
				UpgradeSlots.SlotState.EMPTY,
				Color("d4a94f")
			)
		_:
			evolution_label.text = "EVOLUTION"
			_set_locked_tree_slot(
				evolution_slot,
				0,
				"Evolution unlocks once two lines in each Core Adaptation reach rank 3."
			)


func _set_path_emblem(
	label: Label,
	icon: TextureRect,
	path_id: int,
	selected: bool,
	accent: Color
) -> void:
	label.visible = not selected
	icon.visible = selected
	if not selected:
		label.text = "?"
		label.modulate = accent.lightened(0.22)
		icon.texture = null
		return
	label.text = ""
	icon.texture = _get_path_emblem_texture(path_id)
	icon.modulate = _get_path_emblem_tint(path_id, accent)


func _get_path_emblem_texture(path_id: int) -> Texture2D:
	match path_id:
		Progression.PathId.SPORE:
			return ADAPTATION_ICON_SPORE
		Progression.PathId.BLOOM:
			return ADAPTATION_ICON_BLOOM
		Progression.PathId.BRAMBLE:
			return ADAPTATION_ICON_BRAMBLE
		Progression.PathId.ROOT:
			return ADAPTATION_ICON_ROOT
		Progression.PathId.PRUNING:
			return ADAPTATION_ICON_PRUNING
		Progression.PathId.THISTLE:
			return ADAPTATION_ICON_THISTLE
		Progression.PathId.VINE:
			return ADAPTATION_ICON_VINE
		Progression.PathId.FRUIT:
			return ADAPTATION_ICON_FRUIT
	return null


func _get_path_emblem_tint(path_id: int, accent: Color) -> Color:
	# Bloom and Fruit already carry their authored colour. The remaining source
	# art is white/off-white and takes on the path colour here without duplicating
	# recoloured raster files.
	if path_id in [Progression.PathId.BLOOM, Progression.PathId.FRUIT]:
		return Color.WHITE
	return accent.lightened(0.22)


func _set_locked_tree_slot(row: UpgradeSlots, index: int, tooltip: String) -> void:
	row.set_slot(
		index,
		"",
		"",
		tooltip,
		UpgradeSlots.SlotState.LOCKED
	)


func _get_path_upgrade_ids(path_id: int) -> PackedInt32Array:
	var ids := PackedInt32Array()
	if path_id == Progression.UNSELECTED_PATH:
		return ids
	for upgrade_id in range(Progression.UpgradeId.size()):
		if _progression._get_upgrade_path(upgrade_id) == path_id:
			ids.append(upgrade_id)
	return ids


func _get_path_hud_color(path_id: int) -> Color:
	match path_id:
		Progression.PathId.SPORE:
			return Color("68a96a")
		Progression.PathId.BLOOM:
			return Color("9b68b5")
		Progression.PathId.BRAMBLE:
			return Color("798f45")
		Progression.PathId.ROOT:
			return Color("b18449")
		Progression.PathId.PRUNING:
			return Color("b66255")
		Progression.PathId.THISTLE:
			return Color("a76ca8")
		Progression.PathId.VINE:
			return Color("4f9c76")
		Progression.PathId.FRUIT:
			return Color("c17d45")
	return Color("596052")


func _on_slot_hovered(index: int, row: UpgradeSlots) -> void:
	var description := row.get_slot_tooltip(index)
	if description.is_empty():
		return
	var title := description.get_slice("\n", 0).strip_edges()
	# Reported rather than shown: the tooltip stack is shared with reward hovers
	# that have nothing to do with this panel, so the run root owns it.
	slot_hovered.emit(
		title, MechanicsHelp.tooltip_body(description, title), row.get_slot_global_rect(index)
	)



func _owned_ordinary_rank_total() -> int:
	var total := 0
	for path_id in _progression.get_owned_adaptations():
		for upgrade_id in _progression.get_adaptation_line_ids(path_id):
			total += _progression.get_owned_upgrade_level(upgrade_id)
	return total
