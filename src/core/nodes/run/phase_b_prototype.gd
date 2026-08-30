class_name PhaseBPrototype
extends Node2D

const RUN_MODE := preload("res://src/core/models/run/phase_b_run_mode.gd")

## Placeholder reel faces. Each stands for one Path, plus the Clover wild and the Bust.
const SYMBOL_SEED := preload("res://assets/art/slots/symbols/symbol_seed.svg")
const SYMBOL_FLOWER := preload("res://assets/art/slots/symbols/symbol_flower.svg")
const SYMBOL_BRAMBLE := preload("res://assets/art/slots/symbols/symbol_bramble.svg")
const SYMBOL_ROOT := preload("res://assets/art/slots/symbols/symbol_root.svg")
const SYMBOL_CUTTING := preload("res://assets/art/slots/symbols/symbol_cutting.svg")
const SYMBOL_THISTLE := preload("res://assets/art/slots/symbols/symbol_thistle.svg")
const SYMBOL_VINE := preload("res://assets/art/slots/symbols/symbol_vine.svg")
const SYMBOL_FRUIT := preload("res://assets/art/slots/symbols/symbol_fruit.svg")
const SYMBOL_WILD := preload("res://assets/art/slots/symbols/symbol_wild.svg")
const SYMBOL_BUST := preload("res://assets/art/slots/symbols/symbol_bust.svg")

const ADAPTATION_ICON_SPORE := preload("res://assets/art/adaptation_icons/spore/spore.png")
const ADAPTATION_ICON_BLOOM := preload("res://assets/art/adaptation_icons/bloom/bloom_512x512.png")
const ADAPTATION_ICON_BRAMBLE := preload("res://assets/art/adaptation_icons/bramble/bramble.png")
const ADAPTATION_ICON_ROOT := preload("res://assets/art/adaptation_icons/root/root.png")
const ADAPTATION_ICON_PRUNING := preload("res://assets/art/adaptation_icons/pruning/pruning.png")
const ADAPTATION_ICON_THISTLE := preload("res://assets/art/adaptation_icons/thistle/thistle.svg")
const ADAPTATION_ICON_VINE := preload("res://assets/art/adaptation_icons/vine/vine.png")
const ADAPTATION_ICON_FRUIT := preload("res://assets/art/adaptation_icons/fruit/red-apple.png")

enum RunState {
	RUNNING,
	VICTORY,
	DEFEAT,
}

enum ChoiceKind {
	NONE,
	UPGRADE,
	RELIC,
}

@export_group("Gameplay Components")
## Authoritative territory simulation used for ownership, maturity, and run-loss checks.
@export var territory_field: TerritoryField
## Presentation adapter that draws the territory field and authored Seed/Bloom effects.
@export var overlay: TerritoryPrototypeOverlay
## Player component whose health and movement state this run coordinates.
@export var player: PhaseBPlayer
## Combat component responsible for enemies, Cane, damage, pickups, and combat audio.
@export var combat: PhaseBCombatDirector
## Progression component responsible for XP drafts, Biomass, relics, and evolution.
@export var progression: PhaseBProgression
## Evolutions component owning every Evolution's state and tuning.
@export var evolutions: PhaseBEvolutions
## Ecosystem Metabolism component. It develops Mass, Push and Hold out of the run's
## lifetime earnings and pushes them into the field as territory strength. Nothing
## here is player-facing any more: there is no meter to watch and nothing to spend.
@export var metabolism: PhaseBMetabolism
## The Clover machine. Territory is staked here and the reels pay out in Path events.
## Biomass is never touched, so a run can gamble away its body without ever losing the
## growth its lifetime earnings already bought.
@export var slot_machine: PhaseBSlotMachine
## Draws the region on the table over the arena. Its own layer rather than another
## pass inside the effects overlay: a CanvasItem carries one material, and the wager
## needs a shader of its own to come out smooth instead of as a grid of lit cells.
@export var wager_layer: TerritoryWagerLayer
## Layer drawing the temporary shield a Bloom leaves on the Green it touched. Its own
## node for the same reason the wager highlight is: it belongs to the ground rather
## than to the effects drawn on top of it.
@export var aftergrowth_layer: TerritoryAftergrowthLayer
## Chance, drought protection, and the construction of the visible reel faces.
@export var clover_odds: PhaseBCloverOdds
## Which cells a given stake would take right now.
@export var wager_selector: PhaseBWagerSelector
## How long each Path stays lit after the reels pay it out.
@export var clover_jackpots: PhaseBCloverJackpots
## The three seconds a run gets to rebuild after an All In whiff.
@export var all_in_grace: PhaseBAllInGrace
## Relic component that owns every triggered relic: its counters, its cooldowns,
## its per-wave state, and the persistent objects relics leave in the arena.
@export var relic_director: PhaseBRelicDirector
## Wave component responsible for the run timeline, scaling, and enemy reinforcement schedule.
@export var wave_director: PhaseBWaveDirector
## Plant component responsible for Seeds, Blooms, explosions, and Super Bloom chains.
@export var spore_director: PhaseBSporeDirector
## Bloom component that owns the Bloom cadence, detonations, and Bloom evolutions.
@export var bloom_director: PhaseBBloomDirector
## Bramble component that owns that path's tuning and pushes it into the systems.
@export var bramble_director: PhaseBBrambleDirector
## Root component that owns that path's tuning and its field rules.
@export var root_director: PhaseBRootDirector
## Man-Eater component: the Legendary relic's Hunger, its Bite, and the meal it
## turns back into Green.
@export var man_eater: PhaseBManEater
## Pruning component that owns the cycle, its Cuttings, and Pruned Ground.
@export var pruning_director: PhaseBPruningDirector
## Runtime for Thistle turrets, Vine pair effects, rolling Fruit, and their relics.
@export var adaptation_director: PhaseBAdaptationDirector
## Shared SFX and music bus names plus the pause-slider output caps.
@export var audio_settings: PhaseBAudioSettings

@export_group("Boss Feedback")
## Pixel radius of the visible hostile pulse emitted when the boss erupts.
@export_range(16.0, 300.0, 1.0) var eruption_pulse_radius_pixels := 96.0

@export_group("Run Survival")
## Seconds Green territory may remain at zero before the run ends in defeat.
@export_range(0.0, 30.0, 0.5) var zero_territory_grace_seconds := 6.0

@export_group("Input")
## Stick deflection that counts as the player reaching for the controller. Below it
## a resting stick cannot flicker the focus ring on by itself.
@export_range(0.05, 1.0, 0.01) var controller_stick_deadzone := 0.35

@export_group("Root Development")
## How long Conductive Roots leaves its new reach on screen after being bought.
@export_range(0.0, 6.0, 0.1) var conductive_reveal_seconds := 1.6

@export_group("Event Banner")
## Seconds a major-event banner holds the battlefield before it fades away.
@export_range(0.5, 12.0, 0.1) var banner_seconds := 2.60
## Seconds of that time spent fading, so the banner leaves rather than vanishing.
@export_range(0.1, 6.0, 0.1) var banner_fade_seconds := 1.10

@export_group("Ecosystem Feedback")
## How much longer the border's answer to a purchase lingers than the release that
## caused it. A little over one keeps the visual alive to the end of the pour.
@export_range(0.5, 4.0, 0.05) var injection_visual_duration_scale := 1.35

@export_group("Relic Rewards")
## Waves between scheduled relic rewards; every Nth wave puts one on the table.
## Zero turns the schedule off and leaves relics to the elite and the boss.
@export_range(0, 12, 1) var relic_reward_wave_cycle := 3

@export_group("Interface Wiring")
## Audio player that starts and loops the authored ambient forest theme.
@export var ambient_music_audio: AudioStreamPlayer
## The lever going down. Optional, like the two below it: a scene without the player
## simply runs the machine silently rather than failing to load.
@export var slot_lever_audio: AudioStreamPlayer
## One reel coming to rest. Polyphonic, because three reels stop close together and
## the third click must not cut the second one off.
@export var slot_reel_audio: AudioStreamPlayer
## A jackpot landing, path or Clover alike.
@export var slot_jackpot_audio: AudioStreamPlayer
## Progress bar that displays the player's current health fraction.
@export var health_bar: ProgressBar
## Label that displays current and maximum player health numerically.
@export var health_label: Label
## Progress bar that displays the percentage of the arena controlled by Green.
@export var territory_bar: ProgressBar
## Label that displays Green territory percentage and the Seed-progress tooltip.
@export var territory_label: Label
## Progress bar that displays XP earned toward the next level.
@export var xp_bar: ProgressBar
## Label that displays the current level and numerical XP requirement.
@export var xp_label: Label
## Label that displays wave number, wave name, time remaining, and active hostiles.
## The wave counter, on its own node so it can be placed and restyled in the editor
## rather than being padded into position inside a format string.
@export var wave_label: Label
## The run clock, likewise its own node.
@export var clock_label: Label
## The hostile-count warning, its own node so the panel can place it.
@export var hostile_label: Label
## Label that displays selected Plant paths, mastery readiness, and active evolution.
@export var evolution_label: Label
## Label that lists relics acquired during the current run.
@export var relics_label: Label
## Label used for milestone, combat, upgrade, and failure-status messages.
## Row of rounded slots showing which relics the run holds.
@export var relic_slots: PhaseBUpgradeSlots
## Label that names the 13-position Adaptations tree in the side HUD.
@export var slots_label: Label
## Row of rounded slots showing the growth lines the run has taken.
@export var upgrade_slots: PhaseBUpgradeSlots
## Panel shown while the player chooses an upgrade or relic.
@export var choice_panel: Panel
## Heading label for the active upgrade or relic draft.
@export var choice_header: Label
## Button used for the first authored upgrade or relic choice.
@export var choice_button_one: Button
## Button used for the second authored upgrade or relic choice.
@export var choice_button_two: Button
## Button used for the third authored upgrade or relic choice.
@export var choice_button_three: Button
## Button used for a fourth option, which only path offers currently need.
@export var choice_button_four: Button
## Button that spends one of the run's rerolls to redraw the current upgrade offer.
@export var choice_reroll_button: Button

@export_group("Clover Machine")
## Seconds the first matching pair of a run holds the battlefield still while the
## third reel resolves. Once per run and never again: the point is that the first
## time the machine nearly pays out, the game stops to let the player watch it.
## Later pairs still slow the reel and lean the panel in, without the pause.
@export_range(0.0, 1.0, 0.01) var pair_focus_in_seconds := 0.30
@export_range(0.0, 1.0, 0.01) var pair_focus_out_seconds := 0.30
## How much larger the slot panel becomes at full focus.
@export_range(1.0, 3.0, 0.01) var pair_focus_scale := 1.45
## How much larger it becomes for an ordinary later pair, which is a lean rather
## than a cinematic: the doc asks for roughly this and no pause with it.
@export_range(1.0, 2.0, 0.01) var pair_tease_scale := 1.12
## Arena pixels the panel moves inward while focused.
@export_range(0.0, 200.0, 1.0) var pair_focus_inset_pixels := 26.0
## How near two enemies must be to count as standing together when a Bloom jackpot
## looks for something worth landing on.
@export_range(10.0, 400.0, 5.0) var bloom_jackpot_cluster_radius := 78.0
## Smallest gap between two of that jackpot's anchors, so a big win is spread over
## the fight rather than dropped four times onto one mob.
@export_range(10.0, 600.0, 5.0) var bloom_jackpot_anchor_spacing := 96.0
## The three reel windows, left to right. Each clips a two-face strip that scrolls
## through it, so a spin looks like reels turning rather than three icons changing.
@export var reel_one: Control
@export var reel_two: Control
@export var reel_three: Control
## Faces a reel scrolls past per second while it is turning.
@export_range(1.0, 40.0, 0.5) var reel_scroll_speed := 11.0
## Notched wager control. Three positions, because a continuous dial invites fiddling
## and a notch is a decision the player can name.
@export var wager_slider: HSlider
@export var wager_label: Label
## The odds readout under the machine: what a spin currently pays and what it currently
## risks, after drought protection and Bust suppression. The machine is allowed to
## protect the player from ugly randomness; it is not allowed to print a number it is
## not about to roll.
@export var odds_label: Label
## The whole machine, used as the hover region. The wager preview only appears while the
## player is actually looking at the slot: a permanent pulsing overlay would make the
## arena unreadable for the whole of a run that never gambles.
@export var slot_panel: Control
## Centre-arena countdown shown during the All In grace period.
@export var all_in_label: Label
## The lever is the spin. Grabbing it and dragging down is the input; a button beside
## a slot machine would be admitting the machine is decoration.
@export var lever_grab: Control
@export var lever_up: TextureRect
@export var lever_down: TextureRect
## How long the lever stays seated at the bottom of its throw before springing back.
## The art is two frames, up and bottomed out, so the pull is a swap rather than a
## slide: dragging the whole sprite down moved the ball and the shaft and the base
## together, which reads as the lever falling off the machine rather than being pulled.
@export_range(0.05, 2.0, 0.05) var lever_seat_seconds := 0.28
## Large transient banner over the battlefield for major progression events.
@export var banner_label: Label
## Side-panel button that resets the current run to its initial state.
## Panel shown when the run reaches victory or defeat.
@export var result_panel: Panel
## Heading label used for the victory or defeat result.
@export var result_header: Label
## Label that explains the outcome and summarizes final run statistics.
@export var result_detail: Label
## Full-screen interface layer shown while the pause menu is open.
@export var pause_overlay: Control
## Button that closes the pause menu and resumes gameplay.
@export var pause_resume_button: Button
## Slider that controls the SFX bus within the configured output cap.
@export var pause_volume_slider: HSlider
## Label that displays the current SFX slider percentage.
@export var pause_volume_value: Label
## Slider that controls the Music bus independently within its output cap.
@export var pause_music_volume_slider: HSlider
## Label that displays the current Music slider percentage.
@export var pause_music_volume_value: Label
## Button that toggles between windowed and fullscreen display modes.
@export var pause_fullscreen_button: Button
## Opens the presentation options. They used to sit on the pause panel all at once,
## which made pausing mid-fight a wall of rows to read past to reach Resume.
@export var pause_settings_button: Button
## The page those options moved to, shown in place of the pause panel rather than on
## top of it, so there is only ever one thing to read.
@export var pause_settings_panel: Control
@export var pause_settings_back_button: Button
@export var pause_panel: Control
## Opens the alphabetized mechanics reference.
@export var pause_glossary_button: Button
## Button that exits the running game application.
@export var pause_quit_button: Button

@export_group("Presentation Settings")
## The presentation options the pause menu edits and the battlefield reads.
@export_group("Development")
## The debug keys, and the card in the side panel that lists them. Off hides both: the
## keys stop responding and the list stops being shown, so a build handed to someone
## else cannot advertise controls it will not answer, and cannot answer controls it
## does not advertise. One switch for both, because the two drifting apart is the only
## way this is confusing.
@export var dev_controls_enabled := true:
	set(value):
		dev_controls_enabled = value
		_refresh_dev_controls()
## The card itself, hidden along with the keys.
@export var debug_help_label: Label

@export_group("Collaborators")
@export var display_settings: PhaseBDisplaySettings
## Per-spin record of what the Clover machine did. Off unless a playtest turns it
## on, and never read by the machine: an instrument that fed back into the thing it
## measures would stop measuring it.
@export var clover_telemetry: PhaseBCloverTelemetry
## The interface layer, scaled by the UI Scale setting. The battlefield is a
## sibling of it and is deliberately not scaled: the doc's rule is that scaling
## the interface must not change how much arena the player can see.
@export var interface_layer: CanvasLayer
## One button per presentation option. Pressing one advances its setting, which is
## why they are buttons rather than sliders: every option here is a short list of
## authored presets, and a preset list wants a control that names its current value.
@export var setting_button_friendly_effects: Button
@export var setting_button_enemy_telegraphs: Button
@export var setting_button_territory_detail: Button
@export var setting_button_damage_numbers: Button
@export var setting_button_player_highlight: Button

@export_group("Interface Text")
## Wording for the states a control does not sit in at rest, so every line the
## game can print is edited in the editor rather than in code. The resting wording
## is the text on the node itself; these are the alternates it swaps to. All of
## them take named placeholders - {like_this} - and a placeholder that matches
## nothing is printed as typed, which is how a misspelt name shows itself.
@export var wave_grace_template := "WAVE {wave} IN {seconds}s"
@export var clock_complete_text := "CLEAR THE FIELD"
@export var clock_detailed_template := (
	"{clock} REMAINING    MASS {mass}  PUSH {push}  HOLD {hold}"
)
@export var wager_stake_template := "{stake}   {percent}% TERRITORY"
@export var odds_live_template := "JACKPOT {jackpot}%    BUST {bust}%"
@export_multiline var metabolism_complete_template := (
	"LIFETIME BIOMASS {lifetime}
FULLY DEVELOPED"
)
@export var fullscreen_exit_text := "EXIT FULLSCREEN"
@export var volume_unavailable_text := "UNAVAILABLE"
@export var choice_header_upgrade := "ROOT MEMORY"
@export var choice_header_relic := "ELITE RELIC"
@export var choice_header_support_path := "SUPPORT PLANT PATH"
@export_multiline var choice_evolution_template := "{name}   EVOLUTION
{detail}"
@export_multiline var choice_upgrade_template := (
	"{name}   LEVEL {level} → {next}
{detail}"
)
## Row added under a line the Root Network amplifies, on the draft buttons and in the
## upgrade hover alike. It names the multiplier and then the number the line actually
## resolves to once Mature ground has been applied, so the player is never left to do
## the arithmetic themselves.
@export_multiline var root_potency_note_template := "ROOTED {multiplier}x → {effect}"
@export_multiline var choice_relic_template := "{name}   {rarity}
{detail}"
@export var result_victory_header := "FRONTIER HELD"
@export var result_defeat_header := "THE FRONTIER WITHERED"
@export_multiline var result_detail_template := (
	"{detail}

Time  {time}    Level  {level}    Green  {green}%"
)
@export var action_aiming_template := "{action}  CHOOSE TARGET"
@export var action_cooldown_template := "{action}  {seconds}s"

var choice_buttons: Array[Button] = []
## Setting buttons indexed by PhaseBDisplaySettings.OptionId, so one loop drives
## all seven and an eighth option is one entry rather than a seventh copy.
var setting_buttons: Array[Button] = []

var _run_state := RunState.RUNNING
var _final_stand_announced := false
## Every dynamic line in the interface, as the scene authored it. Captured once,
## before anything writes to a control, so what is typed in the editor is what the
## game prints - wording, spacing, order, and which values appear at all.
var _authored := AuthoredText.new()
var _choice_kind := ChoiceKind.NONE
var _choice_ids := PackedInt32Array()
var _zero_territory_remaining := 0.0
var _owed_wave_relics := 0
var _banner_remaining := 0.0
## Whether the run is currently choosing where to put a release, and which action is
## waiting on the answer. The run keeps running while it is: the doc treats a release
## as a decision made under pressure, not a pause to plan in.
## Seconds left of the reach ring Circulation throws up when it is developed, so the
## development shows the player what it just widened.
var _conductive_reveal_remaining := 0.0
## The first-pair cinematic. Zero when nothing is focused; while it runs the rest
## of the run is held still and only the machine advances.
var _pair_focus_remaining := 0.0
var _pair_focus_total := 0.0
## Whether that focus is the once-per-run cinematic, which pauses, or an ordinary
## later tease, which only leans the panel in.
var _pair_focus_is_cinematic := false
## The slot panel's authored rect, captured before anything scales it, so the focus
## always returns to where the scene put it rather than to wherever it last was.
var _slot_panel_home := Rect2()
var _slot_panel_home_captured := false
var _lever_seated := false
## How many of the slot's hover regions the pointer is currently inside.
var _slot_hover_regions := 0
var _lever_seat_remaining := 0.0
## What each reel is currently showing and what is coming up behind it, plus how far
## the strip has scrolled. Rest positions are read from the scene so an idle reel sits
## exactly where the scene put it.
var _reel_symbol := PackedInt32Array([5, 5, 5])
var _reel_incoming := PackedInt32Array([5, 5, 5])
var _reel_offset := PackedFloat32Array([0.0, 0.0, 0.0])
var _reel_rest_a := PackedFloat32Array([0.0, 0.0, 0.0])
var _reel_rest_b := PackedFloat32Array([0.0, 0.0, 0.0])
## Whether the last input came from a controller. The focus ring is a controller
## affordance: with a mouse in hand it is a white box sitting on a button nobody is
## about to press, so it is only shown once a pad is actually being used.
var _controller_active := false
## Authored row lengths, captured before the rows are trimmed to what the run has.
var _maximum_relic_slots := 6
var _hud_accumulator := 0.0
var _base_natural_spread_rate := 0.0
var _base_maturity_resistance_bonus := 0.0
var _base_pressure_advection := 0.0
var _base_small_fragment_decay := 0.0
var _pause_menu_open := false
var _pause_settings_open := false
var _glossary_button: Button
var _mechanics_help: PhaseBMechanicsHelp
var _sfx_bus_index := -1
var _music_bus_index := -1
@onready var _secondary_upgrade_slots: PhaseBUpgradeSlots = %Path2Slots
@onready var _evolution_upgrade_slot: PhaseBUpgradeSlots = %EvolutionSlot
@onready var _support_upgrade_slots: PhaseBUpgradeSlots = %SupportSlots
@onready var _path_one_label: Label = %Path1Label
@onready var _path_two_label: Label = %Path2Label
@onready var _support_path_label: Label = %SupportPathLabel
@onready var _evolution_tree_label: Label = %EvolutionTreeLabel
@onready var _path_one_emblem: Label = %Path1EmblemLabel
@onready var _path_two_emblem: Label = %Path2EmblemLabel
@onready var _support_path_emblem: Label = %SupportEmblemLabel
@onready var _path_one_emblem_icon: TextureRect = %Path1EmblemIcon
@onready var _path_two_emblem_icon: TextureRect = %Path2EmblemIcon
@onready var _support_path_emblem_icon: TextureRect = %SupportEmblemIcon
@onready var _support_path_emblem_lock: TextureRect = %SupportEmblemLock


func _ready() -> void:
	var run_mode := RUN_MODE.get_selected()
	wave_director.configure_mode(run_mode)
	progression.configure_mode(run_mode)
	PhaseBNinePatchButtonBorder.install_under(self)
	PhaseBNinePatchPanelBorder.install_under(self)
	assert(territory_field != null, "PhaseBPrototype requires TerritoryField")
	assert(overlay != null, "PhaseBPrototype requires TerritoryPrototypeOverlay")
	assert(player != null, "PhaseBPrototype requires PhaseBPlayer")
	assert(combat != null, "PhaseBPrototype requires PhaseBCombatDirector")
	assert(progression != null, "PhaseBPrototype requires PhaseBProgression")
	assert(wave_director != null, "PhaseBPrototype requires PhaseBWaveDirector")
	assert(spore_director != null, "PhaseBPrototype requires PhaseBSporeDirector")
	assert(bloom_director != null, "PhaseBPrototype requires PhaseBBloomDirector")
	assert(bramble_director != null, "PhaseBPrototype requires PhaseBBrambleDirector")
	assert(root_director != null, "PhaseBPrototype requires PhaseBRootDirector")
	assert(man_eater != null, "PhaseBPrototype requires PhaseBManEater")
	assert(metabolism != null, "PhaseBPrototype requires PhaseBMetabolism")
	assert(slot_machine != null, "PhaseBPrototype requires PhaseBSlotMachine")
	assert(wager_layer != null, "PhaseBPrototype requires TerritoryWagerLayer")
	assert(clover_odds != null, "PhaseBPrototype requires PhaseBCloverOdds")
	assert(wager_selector != null, "PhaseBPrototype requires PhaseBWagerSelector")
	assert(clover_jackpots != null, "PhaseBPrototype requires PhaseBCloverJackpots")
	assert(all_in_grace != null, "PhaseBPrototype requires PhaseBAllInGrace")
	assert(relic_director != null, "PhaseBPrototype requires PhaseBRelicDirector")
	assert(pruning_director != null, "PhaseBPrototype requires PhaseBPruningDirector")
	assert(audio_settings != null, "PhaseBPrototype requires PhaseBAudioSettings")
	# The authored row lengths are the ceiling the run grows toward, so they are
	# read once before either row is trimmed to what the run currently holds.
	if relic_slots != null:
		_maximum_relic_slots = relic_slots.slot_count
	assert(banner_label != null, "PhaseBPrototype requires the event banner")
	assert(ambient_music_audio != null, "PhaseBPrototype requires its ambient music player")
	choice_buttons = [
		choice_button_one,
		choice_button_two,
		choice_button_three,
		choice_button_four,
	]
	setting_buttons = [
		setting_button_friendly_effects,
		setting_button_enemy_telegraphs,
		setting_button_territory_detail,
		setting_button_damage_numbers,
		setting_button_player_highlight,
	]
	var required_interface_controls: Array[Control] = [
		health_bar,
		health_label,
		territory_bar,
		territory_label,
		xp_bar,
		xp_label,
		wave_label,
		clock_label,
		hostile_label,
		evolution_label,
		relics_label,
		relic_slots,
		slots_label,
		upgrade_slots,
		choice_panel,
		choice_header,
		choice_button_one,
		choice_button_two,
		choice_button_three,
		choice_button_four,
		choice_reroll_button,
		result_panel,
		result_header,
		result_detail,
		pause_overlay,
		pause_resume_button,
		pause_volume_slider,
		pause_volume_value,
		pause_music_volume_slider,
		pause_music_volume_value,
		pause_fullscreen_button,
		pause_glossary_button,
		pause_quit_button,
	]
	# Before a single frame runs, and so before anything below overwrites a control:
	# from here on the editor owns the wording and this script only fills in numbers.
	_authored.capture(required_interface_controls)
	_authored.capture([
		wager_label,
		odds_label,
		all_in_label,
		banner_label,
	])
	_authored.capture(setting_buttons)
	# Tooltips are authored the same way, on the same nodes.
	_authored.capture(required_interface_controls, "tooltip_text")
	_authored.capture(setting_buttons, "tooltip_text")
	# An axis button draws its wording through a child caption, so its template is
	# the button's own `display_text` rather than the Button `text` nothing shows.
	for interface_control in required_interface_controls:
		assert(
			interface_control != null,
			"PhaseBPrototype has an unwired Interface reference at index %d of %d"
			% [required_interface_controls.find(interface_control), required_interface_controls.size()]
		)

	_base_natural_spread_rate = territory_field.tuning.natural_spread_rate
	_base_maturity_resistance_bonus = territory_field.tuning.maturity_resistance_bonus
	_base_pressure_advection = territory_field.tuning.pressure_advection
	_base_small_fragment_decay = territory_field.tuning.small_fragment_decay_per_second

	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	combat.xp_collected.connect(progression.add_xp)
	combat.elite_defeated.connect(_on_elite_defeated)
	combat.boss_defeated.connect(_on_boss_defeated)
	wave_director.wave_began.connect(_on_wave_began)
	wave_director.elite_arrived.connect(_on_elite_arrived)
	wave_director.boss_arrived.connect(_on_boss_arrived)
	wave_director.final_invasion_began.connect(_on_final_invasion_began)
	wave_director.cleanup_began.connect(_on_cleanup_began)
	spore_director.status_requested.connect(_set_status)
	bloom_director.status_requested.connect(_set_status)
	combat.boss_erupted.connect(_on_boss_erupted)
	man_eater.status_requested.connect(_set_status)
	lever_grab.gui_input.connect(_on_lever_input)
	wager_slider.value_changed.connect(_on_wager_changed)
	slot_machine.spin_started.connect(_on_reels_started)
	slot_machine.reel_stopped.connect(_on_reel_stopped)
	slot_machine.pair_tease_started.connect(_on_pair_tease_started)
	slot_machine.spin_resolved.connect(_on_spin_resolved)
	slot_machine.path_jackpot.connect(_on_path_jackpot)
	slot_machine.clover_jackpot.connect(_on_clover_jackpot)
	slot_machine.all_in_wiped.connect(_on_all_in_wiped)
	slot_machine.all_in_ruined.connect(_on_all_in_ruined)
	slot_machine.wager_preview_changed.connect(_on_wager_preview_changed)
	# Bramble and Root do not read their levels every frame: they push their numbers into
	# the field and the combat loop once, whenever the build changes. A jackpot changes
	# the build for ten seconds without anything else noticing, so it has to say so at
	# both ends. Without this the timed jackpots raised levels nobody read and nothing
	# happened on the ground at all.
	clover_jackpots.jackpot_started.connect(_on_jackpot_window_changed)
	clover_jackpots.jackpot_ended.connect(_on_jackpot_window_ended)
	all_in_grace.grace_started.connect(_on_all_in_grace_started)
	all_in_grace.grace_recovered.connect(_on_all_in_grace_recovered)
	all_in_grace.grace_failed.connect(_on_all_in_grace_failed)
	# The machine, the stake meter and the lever all count as looking at the slot. Only
	# the panel would do if its children ignored the mouse, but the slider and the lever
	# grab take input, and hovering either of those would otherwise read as leaving.
	for hover_region in [slot_panel, wager_slider, lever_grab]:
		if hover_region == null:
			continue
		hover_region.mouse_entered.connect(_on_slot_hover_changed.bind(true))
		hover_region.mouse_exited.connect(_on_slot_hover_changed.bind(false))
	metabolism.status_requested.connect(_set_status)
	relic_director.status_requested.connect(_set_status)
	progression.relics_changed.connect(relic_director.apply_relics)
	pruning_director.status_requested.connect(_set_status)
	adaptation_director.status_requested.connect(_set_status)
	progression.upgrade_choice_requested.connect(_on_upgrade_choice_requested)
	progression.relic_choice_requested.connect(_on_relic_choice_requested)
	progression.upgrades_changed.connect(_apply_progression_modifiers)
	progression.paths_changed.connect(_apply_progression_modifiers)
	progression.metabolism_changed.connect(_apply_progression_modifiers)
	progression.relics_changed.connect(_apply_progression_modifiers)
	progression.evolution_changed.connect(_on_evolution_changed)
	progression.xp_changed.connect(_on_xp_changed)
	territory_field.metrics_changed.connect(_on_territory_metrics_changed)

	for index in range(choice_buttons.size()):
		choice_buttons[index].pressed.connect(_choose_displayed_option.bind(index))
	for index in range(setting_buttons.size()):
		if setting_buttons[index] == null:
			continue
		setting_buttons[index].pressed.connect(_cycle_setting.bind(index))
	display_settings.settings_changed.connect(_on_display_settings_changed)
	_on_display_settings_changed()
	choice_reroll_button.pressed.connect(_reroll_upgrade_choice)
	progression.rerolls_changed.connect(_on_rerolls_changed)
	pause_resume_button.pressed.connect(_close_pause_menu)
	pause_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	pause_music_volume_slider.value_changed.connect(_on_music_volume_changed)
	pause_fullscreen_button.pressed.connect(_toggle_fullscreen)
	if pause_settings_button != null:
		pause_settings_button.pressed.connect(_show_pause_settings.bind(true))
	if pause_settings_back_button != null:
		pause_settings_back_button.pressed.connect(_show_pause_settings.bind(false))
	pause_glossary_button.pressed.connect(_open_glossary)
	pause_quit_button.pressed.connect(_quit_from_pause_menu)
	_build_mechanics_help()
	_configure_ambient_music()
	_configure_volume_control()
	_update_fullscreen_button()

	overlay.show_annotations = false
	_capture_reel_rest_positions()
	reset_run()
	_refresh_dev_controls()

func _process(delta: float) -> void:
	# The focus runs on its own clock outside the run, because the whole point of the
	# cinematic is that the run is not running while it plays.
	_advance_pair_focus(delta)
	if (
		_run_state == RunState.RUNNING
		and _choice_kind == ChoiceKind.NONE
		and not _pause_menu_open
		and not is_pair_cinematic_active()
	):
		advance_run(delta)
	# Rebuilt every frame rather than on the HUD's tenth-of-a-second clock: the shield
	# is being eaten in real time and a stuttering sheet would read as the shield
	# itself flickering. The layer costs nothing while no shield exists.
	if aftergrowth_layer != null:
		aftergrowth_layer.refresh()
	_hud_accumulator += delta
	if _hud_accumulator >= 0.10:
		_hud_accumulator = 0.0
		_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	_note_input_device(event)
	# Held rather than toggled, and it does not stop the run. The doc allows inspect to
	# be a live overlay where readability permits, and holding it means the player
	# cannot leave it up by accident while the battlefield needs them.
	if event is InputEventKey and not event.echo and event.keycode == KEY_TAB:
		if not dev_controls_enabled:
			return
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:
		if _mechanics_help != null and _mechanics_help.is_glossary_open():
			_close_glossary()
			get_viewport().set_input_as_handled()
			return
		if _pause_menu_open and _pause_settings_open:
			# Escape backs out of the settings page first, so the key never closes the
			# whole menu out from under a player who only opened a page with it.
			_show_pause_settings(false)
		elif _pause_menu_open:
			_close_pause_menu()
		elif _choice_kind == ChoiceKind.NONE:
			_open_pause_menu()
		get_viewport().set_input_as_handled()
		return
	if _pause_menu_open:
		return
	# Reset comes first and is never gated: it is advertised on the interface itself
	# rather than on the dev card, and a player pressing it is using the game rather
	# than inspecting it.
	match event.keycode:
		KEY_R:
			reset_run()
			return
	# Everything past here is a debug key and answers only while the dev controls are on.
	if not dev_controls_enabled:
		return
	match event.keycode:
		KEY_F2:
			# The guide's wager debug, printed rather than drawn: what it has to show is
			# eight numbers about one region, and eight numbers are easier to read in a
			# log than in an overlay competing with the region itself.
			_report_wager_debug()
		KEY_F3:
			# The guide's odds debug. It prints what this spin would actually roll, after
			# drought protection and Bust anti-streaking, which is the same number the
			# panel prints: the readout may not misreport what the machine will do.
			_report_odds_debug()
		KEY_F5:
			# Phase 1 of the Root Metabolism rework needs establishment to be
			# visible while the real game is running, not only in the territory
			# sandbox where the debug fields already lived.
			var view_name := territory_field.cycle_debug_view()
			territory_field.refresh_visuals_now()
			_set_status("Debug field: %s." % view_name)
		KEY_F6:
			debug_advance_time(120.0)
		KEY_F7:
			progression.add_xp(progression.get_required_xp())
			_set_status("Debug: enough XP added for the next upgrade choice.")
		KEY_F8:
			progression.debug_complete_evolution_requirements()
			_set_status(
				"Debug: %s mastery completed; the evolution is offered at the next level."
				% _get_path_pair_label()
			)
		KEY_F9:
			if wave_director.debug_spawn_boss():
				_set_status("Debug: the Burrower has surfaced early.")
		KEY_F10:
			# The relic pool is far larger than a run sees, so testing one by hand
			# needs a way to be offered relics without farming elites.
			if progression.request_relic_choice():
				_set_status("Debug: a relic reward is on the table.")
		KEY_F11:
			_report_man_eater_state()


func _report_wager_debug() -> void:
	# Everything the guide asks a wager debug to show, measured on the region the
	# machine would actually stake if the lever moved now.
	var seed_position := player.get_arena_position()
	var seed_cell := territory_field.local_to_cell_index(seed_position)
	var stake := slot_machine.get_stake()
	var preview := slot_machine.get_preview_cells()
	var committed := slot_machine.get_committed_cells()
	var maturity := 0.0
	var exposure := 0.0
	for cell in preview:
		maturity += territory_field.get_cell_maturity(cell)
		exposure += territory_field.get_cell_boundary_exposure(cell)
	var sampled := maxf(1.0, float(preview.size()))
	var report := (
		"CLOVER WAGER  seed cell %d  stake %s  target %d  selected %d  committed %d  "
		% [
			seed_cell,
			CloverSlot.get_stake_name(stake),
			wager_selector.get_target_cell_count(
				stake,
				territory_field.get_player_cell_count()
			),
			preview.size(),
			committed.size(),
		]
		+ "maturity %.3f  exposure %.3f  component %d"
		% [
			maturity / sampled,
			exposure / sampled,
			territory_field.get_component_id_at_local(seed_position),
		]
	)
	print(report)
	_set_status(report)


func _report_odds_debug() -> void:
	var stake := slot_machine.get_stake()
	var odds := clover_odds.get_effective_odds(stake)
	var report := (
		"CLOVER ODDS  stake %s  jackpot %.3f (base %.3f + drought %.3f)  clover %.3f  "
		% [
			CloverSlot.get_stake_name(stake),
			float(odds["path_jackpot"]),
			clover_odds.path_jackpot_chances[
				clampi(stake, 0, clover_odds.path_jackpot_chances.size() - 1)
			],
			clover_odds.get_drought_bonus(stake),
			float(odds["triple_clover"]),
		]
		+ "bust %.3f (x%.2f)  whiff %.3f  drought %d  spins since bust %d"
		% [
			float(odds["triple_bust"]),
			clover_odds.get_bust_multiplier(),
			float(odds["whiff"]),
			clover_odds.get_drought(stake),
			clover_odds.get_spins_since_bust(),
		]
	)
	if clover_telemetry != null and clover_telemetry.get_row_count() > 0:
		report += "\n%s" % clover_telemetry.describe_run()
	print(report)
	_set_status(report)


func _report_man_eater_state() -> void:
	# Which enemies are marked is invisible until one dies, so a run that has not
	# seen a Maw come up has no way to tell whether it is close. This prints what
	# the relic is actually holding.
	var report := (
		"MAN-EATER  held=%s  marked %d  maws %d  eruptions %d  cooldown %.2fs"
		% [
			"yes" if man_eater.is_held() else "no",
			man_eater.get_marked_count(),
			man_eater.get_active_maw_count(),
			man_eater.get_eruption_count(),
			man_eater.get_cooldown_remaining(),
		]
	)
	print(report)
	_set_status(report)


func advance_run(delta: float) -> void:
	if delta <= 0.0 or _run_state != RunState.RUNNING:
		return
	# The reserve is Progression's, produced by how much Green the run holds and how
	# much of it has matured. Earning is also what develops the three physical axes,
	# so a run that holds ground is a run that becomes physically capable of holding
	# more of it.
	progression.tick_biomass(
		delta,
		territory_field.get_player_percent(),
		territory_field.get_mature_player_percent(),
		1.0
	)
	slot_machine.advance(delta)
	slot_machine.advance_preview(delta, player.get_arena_position())
	clover_jackpots.advance(delta)
	all_in_grace.advance(delta)
	_advance_all_in_countdown()
	_advance_lever(delta)
	_advance_reels(delta)

	wave_director.advance(delta)
	# Path milestones share the panel with relic rewards and land on the same wave
	# boundaries, so the path choice is asked first and the relic waits its turn.
	_request_due_support_choice()
	_grant_owed_wave_relic()
	if _choice_kind != ChoiceKind.NONE:
		return
	metabolism.advance(delta)
	relic_director.advance(delta)
	spore_director.advance(delta)
	bloom_director.advance(delta)
	bramble_director.advance(delta)
	bramble_director.advance_relics(delta)
	man_eater.advance(delta)
	pruning_director.advance(delta)
	_update_territory_failure(delta)
	_advance_banner(delta)

	if wave_director.is_complete():
		# The timeline running out stops reinforcements; it does not win the run.
		# Whatever is still standing has to be cleared first.
		if not _final_stand_announced:
			_final_stand_announced = true
			_set_status(
				"FINAL STAND — the invasion is spent. Clear the last hostiles to win."
			)
		if combat.get_active_enemy_count() == 0:
			_finish_run(true, "The final invasion broke against a living frontier.")


func reset_run() -> void:
	# Neither a release nor a cinematic can be left half-played across a run boundary.
	_pair_focus_remaining = 0.0
	_pair_focus_is_cinematic = false
	_apply_slot_focus(1.0)
	overlay.clear_overgrow_aim()
	_run_state = RunState.RUNNING
	_final_stand_announced = false
	_choice_kind = ChoiceKind.NONE
	_choice_ids.clear()
	_pause_menu_open = false
	_zero_territory_remaining = zero_territory_grace_seconds
	_owed_wave_relics = 0
	_hud_accumulator = 999.0
	choice_panel.visible = false
	result_panel.visible = false
	pause_overlay.visible = false
	territory_field.tuning.natural_spread_rate = _base_natural_spread_rate
	territory_field.tuning.maturity_resistance_bonus = _base_maturity_resistance_bonus
	territory_field.tuning.pressure_advection = _base_pressure_advection
	territory_field.tuning.small_fragment_decay_per_second = _base_small_fragment_decay
	root_director.reset_director()
	territory_field.simulation_paused = false
	overlay.effects_paused = false
	overlay.clear_effects()
	territory_field.reset_field()
	progression.reset_progression()
	metabolism.reset_metabolism()
	clover_odds.reset_odds()
	clover_jackpots.reset_jackpots()
	all_in_grace.reset_grace()
	slot_machine.reset_machine()
	if clover_telemetry != null:
		clover_telemetry.reset_telemetry()
	wager_layer.clear_wager()
	if all_in_label != null:
		all_in_label.visible = false
	_lever_seated = false
	_reel_offset = PackedFloat32Array([0.0, 0.0, 0.0])
	_reel_symbol = slot_machine.get_last_symbols().duplicate()
	_reel_incoming = slot_machine.get_last_symbols().duplicate()
	_refresh_lever()
	_refresh_reels()
	relic_director.reset_director()
	player.reset_player()
	combat.reset_combat()
	wave_director.reset_director()
	spore_director.reset_director()
	bloom_director.reset_director()
	bramble_director.reset_director()
	man_eater.reset_man_eater()
	pruning_director.reset_director()
	adaptation_director.reset_adaptations()
	_refresh_simulation_pause()
	_apply_progression_modifiers()
	_set_status("The frontier is alive. Move with WASD; Cane sweeps automatically.")
	_update_hud()


func debug_advance_time(seconds: float) -> void:
	if _run_state != RunState.RUNNING:
		return
	wave_director.debug_advance_time(seconds)
	_request_due_support_choice()
	_grant_owed_wave_relic()
	_set_status("Debug: timeline advanced to %s." % _format_time(get_elapsed_seconds()))
	_update_hud()


func get_elapsed_seconds() -> float:
	return wave_director.elapsed_seconds


func get_run_state() -> int:
	return _run_state


func get_kills_toward_seed() -> int:
	return spore_director.get_kills_toward_seed()


func get_current_wave_number() -> int:
	return wave_director.get_current_wave_number()


func is_wave_grace_period_active() -> bool:
	return wave_director.is_grace_period_active()


func get_wave_grace_remaining_seconds() -> float:
	return wave_director.get_grace_remaining_seconds()


func _update_territory_failure(delta: float) -> void:
	# An All In whiff runs its own clock, with its own number on screen. Letting the
	# ordinary extinction countdown run alongside it would mean two deadlines racing
	# and the visible one not being the one that decided the run.
	if all_in_grace.is_suppressing_defeat():
		_zero_territory_remaining = zero_territory_grace_seconds
		return
	if territory_field.get_player_percent() > 0.01:
		_zero_territory_remaining = zero_territory_grace_seconds
		return
	_zero_territory_remaining -= delta
	if _zero_territory_remaining <= 0.0:
		_finish_run(false, "Green territory remained extinct beyond the grace period.")


func _on_wave_began(wave_number: int) -> void:
	if relic_reward_wave_cycle <= 0 or wave_number % relic_reward_wave_cycle != 0:
		return
	_owed_wave_relics += 1


func _grant_owed_wave_relic() -> void:
	# A wave can turn over while a draft or a path choice is already on the table,
	# so the reward waits for the panel to clear instead of being dropped. An
	# offer that finds nothing left to give pays out as Biomass inside
	# Progression, which still settles the debt.
	if _owed_wave_relics <= 0 or _run_state != RunState.RUNNING:
		return
	if _choice_kind != ChoiceKind.NONE or progression.has_pending_relic_choice():
		return
	_owed_wave_relics -= 1
	if progression.request_relic_choice():
		_set_status(
			"WAVE %d — the frontier yields a relic." % wave_director.get_current_wave_number()
		)


func _on_elite_arrived() -> void:
	_set_status("ELITE ROOTBREAKER — defeat it to choose a relic.")


func _on_boss_arrived() -> void:
	_set_status("THE BURROWER SURFACES — its eruptions erase Green.")


func _on_final_invasion_began() -> void:
	_set_status("FINAL INVASION — hold the frontier for two more minutes.")


func _on_cleanup_began() -> void:
	_set_status("LAST ROOTS — no more reinforcements. Survive the remaining hostiles.")


func _on_elite_defeated() -> void:
	if not progression.request_relic_choice():
		_set_status("Elite defeated; its surplus converted into Biomass.")


func _on_boss_defeated() -> void:
	if progression.request_relic_choice():
		_set_status("BOSS DEFEATED — claim a relic from its remains.")
	else:
		_set_status("Boss defeated; the frontier absorbs its remaining Biomass.")

func _on_upgrade_choice_requested(options: PackedInt32Array) -> void:
	_show_choice(ChoiceKind.UPGRADE, options)


func _on_rerolls_changed(_remaining: int) -> void:
	_update_reroll_button()


func _reroll_upgrade_choice() -> void:
	if _choice_kind == ChoiceKind.RELIC:
		# A relic reward now shows three of a large pool, so redrawing it can
		# genuinely change what is on the table.
		if progression.reroll_relic_choice():
			_set_status(
				"Relic offer redrawn. %d reroll(s) left this run."
				% progression.get_relic_rerolls_remaining()
			)
		return
	if _choice_kind != ChoiceKind.UPGRADE:
		return
	if progression.reroll_upgrade_choice():
		_set_status("Draft rerolled. %d reroll(s) left this run." % progression.rerolls_remaining)


func _update_reroll_button() -> void:
	if not is_instance_valid(choice_reroll_button):
		return
	# Upgrade and relic drafts both sample a pool, so both can be redrawn. Path
	# and Breakthrough offers present every option there is, so they cannot.
	if _choice_kind == ChoiceKind.RELIC:
		choice_reroll_button.visible = true
		var relic_rerolls := progression.get_relic_rerolls_remaining()
		choice_reroll_button.disabled = relic_rerolls <= 0
		_authored.write(choice_reroll_button, {"left": relic_rerolls})
		return
	choice_reroll_button.visible = _choice_kind == ChoiceKind.UPGRADE
	choice_reroll_button.disabled = progression.rerolls_remaining <= 0
	_authored.write(
		choice_reroll_button,
		{"left": progression.rerolls_remaining},
	)


func _on_relic_choice_requested(options: PackedInt32Array) -> void:
	_show_choice(ChoiceKind.RELIC, options)


func _show_choice(kind: int, options: PackedInt32Array) -> void:
	_choice_kind = kind
	_choice_ids = options.duplicate()
	if _mechanics_help != null:
		_mechanics_help.hide_tooltip()
	_update_reroll_button()
	match kind:
		ChoiceKind.UPGRADE:
			choice_header.text = (
				choice_header_support_path
				if progression.is_pending_support_upgrade_choice()
				else choice_header_upgrade
			)
		ChoiceKind.RELIC:
			choice_header.text = choice_header_relic
	for index in range(choice_buttons.size()):
		var button := choice_buttons[index]
		if index >= _choice_ids.size():
			button.visible = false
			continue
		button.visible = true
		button.modulate = Color.WHITE
		var option_id := _choice_ids[index]
		if kind == ChoiceKind.UPGRADE and option_id == PhaseBProgression.EVOLUTION_DRAFT_OPTION:
			var pair_evolution := progression.get_pair_evolution_id()
			button.text = AuthoredText.render(choice_evolution_template, {
				"name": PhaseBEvolutions.get_evolution_name(pair_evolution),
				"detail": PhaseBEvolutions.get_evolution_description(pair_evolution),
			})
		elif kind == ChoiceKind.UPGRADE:
			var current_upgrade_level := progression.get_upgrade_level(option_id)
			# What the rank buys, and under it what the Root Network makes of the
			# line once it is taken. The draft is where the choice is made, so the
			# amplified number belongs on the button and not only in the hover.
			var detail := progression.get_upgrade_description(option_id)
			var rooted := _get_root_potency_note(option_id)
			if not rooted.is_empty():
				detail += "\n%s" % rooted
			button.text = AuthoredText.render(choice_upgrade_template, {
				"name": PhaseBProgression.get_upgrade_name(option_id),
				"level": current_upgrade_level,
				"next": current_upgrade_level + 1,
				"detail": detail,
			})
		elif kind == ChoiceKind.RELIC:
			# Rarity is the readout of how much the relic changes, so it is named
			# on the button rather than only implied by the effect text.
			button.text = AuthoredText.render(choice_relic_template, {
				"name": PhaseBProgression.get_relic_name(option_id),
				"rarity": PhaseBRelicCatalog.get_rarity_name(
					PhaseBRelicCatalog.get_rarity(option_id)
				),
				"detail": progression.get_relic_description(option_id),
			})
			button.modulate = PhaseBRelicCatalog.get_rarity_color(
				PhaseBRelicCatalog.get_rarity(option_id)
			)
		# Reward explanations are rendered by PhaseBMechanicsHelp. Leaving the native
		# tooltip empty prevents a delayed duplicate from appearing over the styled cards.
		button.tooltip_text = ""
	choice_panel.visible = true
	_refresh_simulation_pause()


func _choose_displayed_option(index: int) -> void:
	if index < 0 or index >= _choice_ids.size():
		return
	var selected_id := _choice_ids[index]
	var prior_kind := _choice_kind
	_choice_kind = ChoiceKind.NONE
	_choice_ids.clear()
	choice_panel.visible = false
	_mechanics_help.hide_tooltip()
	_update_reroll_button()
	if prior_kind == ChoiceKind.UPGRADE and selected_id == PhaseBProgression.EVOLUTION_DRAFT_OPTION:
		var evolved_pair := _get_path_pair_label()
		if progression.choose_pair_evolution():
			_set_status("%s has evolved into %s." % [
				evolved_pair,
				PhaseBEvolutions.get_evolution_name(progression.active_evolution),
			])
	elif prior_kind == ChoiceKind.UPGRADE:
		var committed_path := progression.get_upgrade_committed_path(selected_id)
		var commits_primary := not progression.has_primary_path()
		var commits_secondary := progression.has_primary_path() and not progression.has_secondary_path()
		if progression.choose_upgrade(selected_id):
			if committed_path == PhaseBProgression.UNSELECTED_PATH:
				_set_status(
					"Upgrade rooted: %s." % PhaseBProgression.get_upgrade_name(selected_id)
				)
			else:
				_set_status("Upgrade rooted: %s. Your %s path is now %s." % [
					PhaseBProgression.get_upgrade_name(selected_id),
					(
						"primary"
						if commits_primary
						else ("secondary" if commits_secondary else "support")
					),
					PhaseBProgression.get_path_name(committed_path),
				])
	elif prior_kind == ChoiceKind.RELIC:
		if progression.choose_relic(selected_id):
			_set_status("Relic claimed: %s." % PhaseBProgression.get_relic_name(selected_id))
	_request_due_support_choice()
	_grant_owed_wave_relic()
	_refresh_simulation_pause()


func _request_due_support_choice() -> void:
	# The pairing Paths are never offered as Paths. A run commits an Adaptation by
	# drafting one of its upgrade lines, so the only scheduled choice left is the
	# evolved run's support Path -- and that one is a draft of real upgrade lines too.
	if _choice_kind != ChoiceKind.NONE or _run_state != RunState.RUNNING:
		return
	if (
		progression.is_tertiary_path_available()
		and get_elapsed_seconds() >= wave_director.tertiary_path_choice_seconds
	):
		progression.request_tertiary_upgrade_choice()


func _cycle_setting(option_id: int) -> void:
	display_settings.cycle_choice(option_id)


func _on_display_settings_changed() -> void:
	# One place applies everything, because several of these change the same frame and
	# each having its own listener would apply them in whatever order the connections
	# happened to be made in.
	if interface_layer != null:
		interface_layer.transform = Transform2D.IDENTITY
	_update_setting_buttons()
	if is_node_ready():
		_update_hud()
	if player != null:
		player.queue_redraw()
	if overlay != null:
		overlay.queue_redraw()


func _update_setting_buttons() -> void:
	for option_id in range(setting_buttons.size()):
		var button := setting_buttons[option_id]
		if button == null:
			continue
		# The name and the current value on one line, because a settings row that only
		# says its value makes the player remember which row is which.
		var option_values := {
			"name": PhaseBDisplaySettings.get_option_name(option_id),
			"value": PhaseBDisplaySettings.get_choice_name(
				option_id,
				display_settings.get_choice(option_id)
			),
			"detail": PhaseBDisplaySettings.get_option_description(option_id),
		}
		# Each row names itself on its own node, so a row can be renamed, reordered
		# or reworded without this loop knowing anything about it.
		_authored.write(button, option_values, "{name}   {value}")
		_authored.write(
			button, option_values, "{name}\n\n{detail}", "tooltip_text"
		)


func _show_banner(text: String) -> void:
	# Major events get the battlefield's attention briefly and then give it back.
	# Nothing here earns a permanent HUD section.
	if banner_label == null:
		return
	# The wording of an event is the event's own; how the banner frames it is the
	# banner's, and that is on the node.
	_authored.write(banner_label, {"event": text}, "{event}")
	banner_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_banner_remaining = banner_seconds


func _advance_banner(delta: float) -> void:
	if _banner_remaining <= 0.0:
		return
	if _conductive_reveal_remaining > 0.0:
		_conductive_reveal_remaining = maxf(0.0, _conductive_reveal_remaining - delta)
		if _conductive_reveal_remaining <= 0.0:
			overlay.clear_overgrow_aim()
	_banner_remaining = maxf(0.0, _banner_remaining - delta)
	var fade := clampf(_banner_remaining / maxf(0.05, banner_fade_seconds), 0.0, 1.0)
	banner_label.modulate = Color(1.0, 1.0, 1.0, fade)


func _on_lever_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not event.pressed:
		return
	_pull_lever()


func _pull_lever() -> void:
	if not slot_machine.try_spin(player.get_arena_position()):
		if not slot_machine.is_buy_in_met():
			_set_status(
				"MINIMUM BUY-IN — %.1f / %.1f%% Established." % [
					slot_machine.get_established_fraction() * 100.0,
					slot_machine.minimum_buyin_established_fraction * 100.0,
				]
			)
		else:
			_set_status("The reels are still turning.")
		return
	# The committed region stops following the player and stops breathing. From here the
	# wager is world-fixed: the player may run anywhere, and the ground on the table is
	# the ground that was on the table when the lever went down.
	wager_layer.set_wager_cells(slot_machine.get_committed_cells(), true)
	_play_slot_sfx(slot_lever_audio)
	_lever_seated = true
	_lever_seat_remaining = lever_seat_seconds
	_refresh_lever()
	_update_slot_controls()


func _advance_lever(delta: float) -> void:
	if not _lever_seated:
		return
	_lever_seat_remaining -= delta
	if _lever_seat_remaining > 0.0:
		return
	_lever_seated = false
	_refresh_lever()


func _refresh_lever() -> void:
	if lever_up == null or lever_down == null:
		return
	# Two frames, swapped. Nothing is moved: the scene placed both layers where the art
	# already puts them, and sliding one of them is what made the pull look wrong.
	lever_up.visible = not _lever_seated
	lever_down.visible = _lever_seated


func _capture_reel_rest_positions() -> void:
	for reel_index in range(3):
		var reel := _reel_window(reel_index)
		if reel == null:
			continue
		var face_a := reel.get_node_or_null("FaceA") as Control
		var face_b := reel.get_node_or_null("FaceB") as Control
		if face_a != null:
			_reel_rest_a[reel_index] = face_a.position.y
		if face_b != null:
			_reel_rest_b[reel_index] = face_b.position.y


func _reel_window(reel_index: int) -> Control:
	match reel_index:
		0:
			return reel_one
		1:
			return reel_two
		_:
			return reel_three


func _advance_reels(delta: float) -> void:
	var moved := false
	for reel_index in range(3):
		var reel := _reel_window(reel_index)
		if reel == null:
			continue
		if reel_index == 2 and _advance_rewind_reel(reel):
			# The third reel is running the fakeout, which drives its own position from
			# the stage the machine is in rather than free-scrolling. The result was
			# decided before any of this moved, so the animation can lie about the near
			# miss without the machine ever lying about the outcome.
			moved = true
			continue
		if slot_machine.is_reel_spinning(reel_index):
			# Turning. The strip scrolls a whole face at a time and takes a new face
			# from the top each time one leaves the bottom, so the window never shows a
			# gap between symbols.
			var cell := maxf(1.0, reel.size.y)
			_reel_offset[reel_index] += reel_scroll_speed * cell * delta
			while _reel_offset[reel_index] >= cell:
				_reel_offset[reel_index] -= cell
				_reel_symbol[reel_index] = _reel_incoming[reel_index]
				_reel_incoming[reel_index] = randi() % CloverSlot.Symbol.size()
			moved = true
		elif _reel_offset[reel_index] != 0.0 or slot_machine.is_revealing():
			# Stopped. It lands on the face the machine already rolled, which is why the
			# reveal can be dramatic without being dishonest.
			_reel_offset[reel_index] = 0.0
			var landed := slot_machine.get_last_symbols()
			if reel_index < landed.size():
				_reel_symbol[reel_index] = landed[reel_index]
			moved = true
	if moved:
		_refresh_reels()


func _advance_rewind_reel(reel: Control) -> bool:
	# The winning face crosses the payline, keeps going, hangs there long enough to
	# read as a miss, and is then dragged back. Nothing here decides anything: the
	# symbol it snaps onto is the one the machine rolled before the lever finished
	# moving, which is what keeps the Easter egg an animation rather than a rig.
	var stage := slot_machine.get_rewind_stage()
	if stage == PhaseBSlotMachine.RewindStage.NONE:
		return false
	var landed := slot_machine.get_last_symbols()
	if landed.size() < 3:
		return false
	var cell := maxf(1.0, reel.size.y)
	var fraction := slot_machine.get_rewind_stage_fraction()
	# The winning face is the one on the strip throughout, so the reversal brings back
	# the same symbol the player watched leave rather than substituting one in.
	_reel_symbol[2] = landed[2]
	match stage:
		PhaseBSlotMachine.RewindStage.PASS:
			# Eased out, so it visibly decelerates as it goes past instead of sailing
			# through at spin speed: the slow is what makes the near miss legible.
			var eased := 1.0 - pow(1.0 - fraction, 2.4)
			_reel_offset[2] = cell * eased
		PhaseBSlotMachine.RewindStage.HOLD:
			_reel_offset[2] = cell
		PhaseBSlotMachine.RewindStage.SNAP:
			# Eased in: slow to start moving back, then hard into the stop, which is
			# what reads as a mechanical lock rather than a slide.
			_reel_offset[2] = cell * (1.0 - fraction * fraction)
	return true


func _refresh_reels() -> void:
	for reel_index in range(3):
		var reel := _reel_window(reel_index)
		if reel == null:
			continue
		var face_a := reel.get_node_or_null("FaceA") as TextureRect
		var face_b := reel.get_node_or_null("FaceB") as TextureRect
		var offset := _reel_offset[reel_index]
		if face_a != null:
			face_a.texture = _symbol_texture(_reel_symbol[reel_index])
			face_a.position.y = _reel_rest_a[reel_index] + offset
			_tint_face(face_a, _reel_symbol[reel_index])
		if face_b != null:
			face_b.texture = _symbol_texture(_reel_incoming[reel_index])
			face_b.position.y = _reel_rest_b[reel_index] + offset
			_tint_face(face_b, _reel_incoming[reel_index])


func _tint_face(face: TextureRect, symbol: int) -> void:
	# The colour goes into the reel shader rather than onto the node, because modulating
	# the node would tint the outline the shader draws along with the shape and put the
	# symbols straight back into the white they were lost in.
	var material := face.material as ShaderMaterial
	if material == null:
		face.modulate = _symbol_fill(symbol)
		return
	material.set_shader_parameter("fill_color", _symbol_fill(symbol))


func _symbol_fill(symbol: int) -> Color:
	# Every face gets its own hue. The art is seven white silhouettes on a near-white
	# reel strip, which read as one smudge in motion; colour plus the black outline the
	# reel shader draws is what lets the eye tell them apart at speed. Shape and colour
	# together, never colour alone, which is the rule the rest of this interface follows:
	# Bust is the only red and it is also the only broken shape.
	match symbol:
		CloverSlot.Symbol.ROOT:
			return Color(0.66, 0.45, 0.25)
		CloverSlot.Symbol.SPORE:
			return Color(0.91, 0.70, 0.23)
		CloverSlot.Symbol.BLOOM:
			return Color(0.89, 0.33, 0.60)
		CloverSlot.Symbol.BRAMBLE:
			return Color(0.60, 0.42, 0.88)
		CloverSlot.Symbol.PRUNING:
			return Color(0.25, 0.72, 0.77)
		CloverSlot.Symbol.THISTLE:
			return Color(0.72, 0.38, 0.70)
		CloverSlot.Symbol.VINE:
			return Color(0.30, 0.66, 0.42)
		CloverSlot.Symbol.FRUIT:
			return Color(0.92, 0.48, 0.22)
		CloverSlot.Symbol.CLOVER:
			return Color(0.31, 0.79, 0.35)
		_:
			return Color(0.88, 0.27, 0.25)


func _on_slot_hover_changed(hovering: bool) -> void:
	# The preview is hover-only. Pulsing the wager region for the whole of a run would
	# put a permanent second overlay on the arena in service of a machine the player is
	# not currently thinking about.
	#
	# Counted rather than latched, because moving from the cabinet onto the stake meter
	# fires an exit and an enter in an order Godot does not promise, and a bare flag
	# would blink the region off and rebuild it every time the pointer crossed a seam.
	_slot_hover_regions = maxi(0, _slot_hover_regions + (1 if hovering else -1))
	slot_machine.set_preview_visible(_slot_hover_regions > 0, player.get_arena_position())


func _on_wager_preview_changed(cells: PackedInt32Array) -> void:
	if cells.is_empty() and not slot_machine.is_revealing():
		wager_layer.clear_wager()
		return
	if slot_machine.is_preview_visible():
		wager_layer.set_wager_cells(cells, false)


func _on_wager_changed(value: float) -> void:
	slot_machine.set_stake(int(round(value)))
	if slot_machine.is_preview_visible():
		# The region grows or shrinks through the organism as the notch moves, so the
		# stake is read as a shape before it is read as a percentage.
		slot_machine.set_preview_visible(false)
		slot_machine.set_preview_visible(true, player.get_arena_position())
	_update_slot_controls()


func _update_slot_controls() -> void:
	if not is_node_ready():
		return
	var stake_name := CloverSlot.get_stake_name(slot_machine.get_stake()).to_upper()
	if not slot_machine.is_buy_in_met():
		# The machine stays visible and says exactly what is missing. Hiding it would
		# make the requirement invisible, and a large tutorial panel would make a
		# two-number condition look like a system.
		_authored.write(wager_label)
		_authored.write(odds_label, {
			"held": "%.1f" % (slot_machine.get_established_fraction() * 100.0),
			"need": "%.1f" % (
				slot_machine.minimum_buyin_established_fraction * 100.0
			),
		})
	else:
		_authored.write_variant(wager_label, wager_stake_template, {
			"stake": stake_name,
			"percent": roundi(slot_machine.get_stake_fraction() * 100.0),
		})
		if odds_label != null:
			# The printed odds are the odds this spin will actually roll, after drought
			# protection and after Bust suppression. The backend may protect the player
			# from ugly randomness; the readout may not misreport what it did.
			var odds := slot_machine.get_effective_odds()
			_authored.write_variant(odds_label, odds_live_template, {
				"jackpot": roundi(float(odds["positive"]) * 100.0),
				"bust": roundi(float(odds["triple_bust"]) * 100.0),
			})
	lever_grab.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if slot_machine.can_spin() else Control.CURSOR_ARROW
	)
	var lever_tint := Color(1.0, 1.0, 1.0) if slot_machine.can_spin() else Color(0.55, 0.6, 0.62)
	lever_up.modulate = lever_tint
	lever_down.modulate = lever_tint


func _symbol_texture(symbol: int) -> Texture2D:
	match symbol:
		CloverSlot.Symbol.SPORE:
			return SYMBOL_SEED
		CloverSlot.Symbol.BLOOM:
			return SYMBOL_FLOWER
		CloverSlot.Symbol.BRAMBLE:
			return SYMBOL_BRAMBLE
		CloverSlot.Symbol.ROOT:
			return SYMBOL_ROOT
		CloverSlot.Symbol.PRUNING:
			return SYMBOL_CUTTING
		CloverSlot.Symbol.THISTLE:
			return SYMBOL_THISTLE
		CloverSlot.Symbol.VINE:
			return SYMBOL_VINE
		CloverSlot.Symbol.FRUIT:
			return SYMBOL_FRUIT
		CloverSlot.Symbol.BUST:
			return SYMBOL_BUST
		_:
			return SYMBOL_WILD


func _on_reels_started(stake: int, committed_cells: PackedInt32Array) -> void:
	# The faces are already decided; what follows is the reveal. The blur is filled with
	# arbitrary symbols so the reels do not appear to scroll through the answer.
	for reel_index in range(3):
		_reel_incoming[reel_index] = randi() % CloverSlot.Symbol.size()
	_set_status("%s stake — %d cells of Green on the table." % [
		CloverSlot.get_stake_name(stake).to_upper(),
		committed_cells.size(),
	])
	_update_slot_controls()


func _on_reel_stopped(_reel_index: int, _symbol: int) -> void:
	_play_slot_sfx(slot_reel_audio)
	_refresh_reels()


func _on_pair_tease_started(symbol: int, first_of_run: bool) -> void:
	# The first two reels agree. Which way that resolves is still unknown - a Bust pair
	# teases exactly as hard as a Path pair - so the line here says what is on the reels
	# and nothing about what is coming.
	_set_status("%s / %s / ?" % [
		CloverSlot.get_symbol_name(symbol).to_upper(),
		CloverSlot.get_symbol_name(symbol).to_upper(),
	])
	if first_of_run:
		_show_banner("%s   %s   ?" % [
			CloverSlot.get_symbol_name(symbol).to_upper(),
			CloverSlot.get_symbol_name(symbol).to_upper(),
		])
	_begin_pair_focus(first_of_run)


func _begin_pair_focus(cinematic: bool) -> void:
	# The focus lasts exactly as long as the third reel has left to run, plus the way
	# in and the way out. Read from the machine rather than authored a second time:
	# a rewind extends the third reel by most of a second, and a cinematic that ended
	# before the reel it is focused on would be the worst possible version of this.
	var reel_remaining := maxf(
		0.0,
		slot_machine.get_reveal_duration() - slot_machine.get_elapsed_seconds()
	)
	_pair_focus_is_cinematic = cinematic
	_pair_focus_total = (
		pair_focus_in_seconds + reel_remaining + pair_focus_out_seconds
	)
	_pair_focus_remaining = _pair_focus_total
	if cinematic:
		# The battlefield stops and the machine does not. Everything else in the run
		# is advanced from advance_run, which the focus gates; the machine is advanced
		# by the focus itself, so the reels keep turning inside the pause.
		_set_simulation_paused(true)


func _advance_pair_focus(delta: float) -> void:
	if _pair_focus_remaining <= 0.0:
		return
	_pair_focus_remaining = maxf(0.0, _pair_focus_remaining - delta)
	if _pair_focus_is_cinematic:
		# The one thing that must keep moving while the world is held: the reels the
		# player is being asked to watch.
		slot_machine.advance(delta)
		_advance_reels(delta)
	var elapsed := _pair_focus_total - _pair_focus_remaining
	var peak := pair_focus_scale if _pair_focus_is_cinematic else pair_tease_scale
	# Three phases, read off one clock: in, hold, out.
	var focus := 1.0
	if elapsed < pair_focus_in_seconds and pair_focus_in_seconds > 0.0:
		focus = elapsed / pair_focus_in_seconds
	elif _pair_focus_remaining < pair_focus_out_seconds and pair_focus_out_seconds > 0.0:
		focus = _pair_focus_remaining / pair_focus_out_seconds
	focus = clampf(focus, 0.0, 1.0)
	# Smoothstepped so the panel eases in and out instead of snapping to size.
	focus = focus * focus * (3.0 - 2.0 * focus)
	_apply_slot_focus(lerpf(1.0, peak, focus))
	if _pair_focus_remaining > 0.0:
		return
	_apply_slot_focus(1.0)
	if _pair_focus_is_cinematic and _run_state == RunState.RUNNING:
		_set_simulation_paused(false)
	_pair_focus_is_cinematic = false


func _apply_slot_focus(scale: float) -> void:
	# The panel is grown about its own centre and pulled inward, rather than being
	# reparented into a proxy: the machine keeps taking input the whole time, which it
	# would not if it were drawn somewhere it does not live.
	if slot_panel == null:
		return
	if not _slot_panel_home_captured:
		_slot_panel_home = Rect2(slot_panel.position, slot_panel.size)
		_slot_panel_home_captured = true
	slot_panel.pivot_offset = _slot_panel_home.size * 0.5
	slot_panel.scale = Vector2(scale, scale)
	var inset := pair_focus_inset_pixels * clampf(scale - 1.0, 0.0, 4.0)
	slot_panel.position = _slot_panel_home.position - Vector2(inset, 0.0)


func is_pair_focus_active() -> bool:
	return _pair_focus_remaining > 0.0


func is_pair_cinematic_active() -> bool:
	return _pair_focus_remaining > 0.0 and _pair_focus_is_cinematic


func _on_spin_resolved(outcome: int, path_symbol: int, stake: int) -> void:
	var faces := PackedStringArray()
	for symbol in slot_machine.get_last_symbols():
		faces.append(CloverSlot.get_symbol_name(symbol).to_upper())
	var detail := CloverSlot.get_outcome_name(outcome)
	if outcome == CloverSlot.Outcome.PATH_JACKPOT:
		detail = "%s JACKPOT" % CloverSlot.get_symbol_name(path_symbol).to_upper()
	_set_status("%s  —  %s." % [" / ".join(faces), detail])
	# Once per spin, here rather than in the jackpot handlers: a Triple Clover raises
	# one clover_jackpot and eight path_jackpots, and the sound is about the spin.
	if (
		outcome == CloverSlot.Outcome.PATH_JACKPOT
		or outcome == CloverSlot.Outcome.TRIPLE_CLOVER
	):
		_play_slot_sfx(slot_jackpot_audio)
	match outcome:
		CloverSlot.Outcome.TRIPLE_CLOVER:
			_show_banner("CLOVER")
			combat.play_plant_explosion_sfx()
		CloverSlot.Outcome.TRIPLE_BUST:
			_show_banner("BUST")
			overlay.spawn_hostile_pulse(player.get_arena_position(), 200.0)
		CloverSlot.Outcome.PATH_JACKPOT:
			_show_banner(CloverSlot.get_symbol_name(path_symbol).to_upper())
			combat.play_plant_explosion_sfx()
		_:
			if stake != CloverSlot.Stake.ALL_IN:
				_set_status("%s  —  the wagered ground drains to neutral." % " / ".join(faces))
	# The highlight goes with the result: a won wager simply stops being highlighted,
	# and a lost one has already been converted underneath it.
	wager_layer.clear_wager()
	_update_slot_controls()


func _on_path_jackpot(path_symbol: int, jackpot_scale: float) -> void:
	# The jackpot runs the real Path at its ceiling rather than a casino-only imitation
	# of it: every line of that Path reads as maxed for as long as the loan lasts, and
	# the Path's own director does the rest without knowing the casino exists. Root,
	# Bramble, Pruning, Thistle, Vine, and Fruit are durations and stack by time;
	# Spore and Bloom are one
	# discrete board-wide event each and stack by simply happening again.
	var path_id := _path_id_for_symbol(path_symbol)
	if path_id < 0:
		return
	clover_jackpots.light(path_id)
	match path_id:
		PhaseBProgression.PathId.SPORE:
			_fire_spore_jackpot(jackpot_scale)
		PhaseBProgression.PathId.BLOOM:
			_fire_bloom_jackpot(jackpot_scale)
		PhaseBProgression.PathId.PRUNING:
			# The casino supplies the clippings outright. Running a harvest cycle would
			# make the jackpot pay for itself out of the player's own Green, and doing
			# nothing would hand them a maxed Pruning with an empty ring and a wait.
			pruning_director.grant_free_cuttings(
				clampi(roundi(4.0 * jackpot_scale), 2, 12)
			)
		PhaseBProgression.PathId.THISTLE, PhaseBProgression.PathId.VINE, PhaseBProgression.PathId.FRUIT:
			adaptation_director.fire_slot_jackpot(path_id, jackpot_scale)


func _on_jackpot_window_changed(path_id: int, total_seconds: float) -> void:
	_apply_progression_modifiers()
	_set_status("%s JACKPOT — %.0f seconds." % [
		PhaseBProgression.get_path_name(path_id).to_upper(),
		total_seconds,
	])


func _on_jackpot_window_ended(_path_id: int) -> void:
	# The loan is over and the numbers have to go back. Re-pushing on the way out matters
	# as much as on the way in: a jackpot that never handed the field its ordinary values
	# back would leave the run permanently maxed on whatever it last won.
	_apply_progression_modifiers()


func _on_clover_jackpot(_jackpot_scale: float) -> void:
	# Triple Clover fires all eight at once and lets them coexist. Serialising them would
	# turn the biggest result the machine has into a queue.
	_show_banner("CLOVER JACKPOT")


func _fire_spore_jackpot(jackpot_scale: float) -> void:
	var anchors := clampi(roundi(5.0 * jackpot_scale), 3, 12)
	for anchor_index in range(anchors):
		overlay.spawn_seed(_jackpot_anchor(anchor_index, anchors))


func _fire_bloom_jackpot(jackpot_scale: float) -> void:
	var anchors := clampi(roundi(4.0 * jackpot_scale), 2, 10)
	# Bloom's jackpot is the one that wants enemies under it. Spore is planting Seeds,
	# which want ground; a Bloom is an explosion, and an explosion placed on empty
	# frontier is a firework. So the anchors are put on the thickest knots of enemies
	# first and only fall back to the frontier when there is nothing to aim at.
	var crowds := _find_enemy_concentrations(anchors)
	for anchor_index in range(anchors):
		var anchor := (
			crowds[anchor_index]
			if anchor_index < crowds.size()
			else _jackpot_anchor(anchor_index, anchors)
		)
		# The real Bloom, with the real material physics behind it. A screen-wide damage
		# pulse would be cheaper and would throw away the thing Bloom actually is.
		bloom_director.plant_chained_bloom(anchor, 0)


func _find_enemy_concentrations(wanted: int) -> PackedVector2Array:
	# The thickest knots of enemies on the board, one anchor each, spaced apart so a
	# jackpot does not put four Blooms on the same mob and leave the rest of the field
	# alone. Scored the same way the Man-Eater picks its meal - by how many others
	# stand with each candidate - because it is the same question asked twice.
	var chosen := PackedVector2Array()
	if wanted <= 0:
		return chosen
	var positions := combat.get_active_enemy_positions()
	if positions.is_empty():
		return chosen
	var radius_squared := (
		bloom_jackpot_cluster_radius * bloom_jackpot_cluster_radius
	)
	var spacing_squared := (
		bloom_jackpot_anchor_spacing * bloom_jackpot_anchor_spacing
	)
	var scores := PackedInt32Array()
	scores.resize(positions.size())
	for index in range(positions.size()):
		var score := 0
		for other in positions:
			if positions[index].distance_squared_to(other) <= radius_squared:
				score += 1
		scores[index] = score
	# Greedy: take the densest remaining knot, then refuse anything standing on top of
	# what has already been taken, and repeat.
	var taken := {}
	while chosen.size() < wanted:
		var best := -1
		var best_score := 0
		for index in range(positions.size()):
			if taken.has(index) or scores[index] <= best_score:
				continue
			var clear := true
			for placed in chosen:
				if positions[index].distance_squared_to(placed) < spacing_squared:
					clear = false
					break
			if clear:
				best = index
				best_score = scores[index]
		if best < 0:
			break
		taken[best] = true
		chosen.append(positions[best])
	return chosen


func _jackpot_anchor(anchor_index: int, anchor_count: int) -> Vector2:
	# Spread around the player and then pulled onto the nearest living frontier, so the
	# event lands where the organism actually meets something rather than in the middle
	# of ground it already owns.
	var angle := TAU * float(anchor_index) / float(maxi(1, anchor_count))
	var reach := 90.0 + 40.0 * float(anchor_index % 3)
	var wanted := player.get_arena_position() + Vector2.from_angle(angle) * reach
	var frontier := territory_field.find_player_frontier_near(wanted)
	return frontier if frontier != Vector2.ZERO else wanted


func _path_id_for_symbol(symbol: int) -> int:
	match symbol:
		CloverSlot.Symbol.ROOT:
			return PhaseBProgression.PathId.ROOT
		CloverSlot.Symbol.SPORE:
			return PhaseBProgression.PathId.SPORE
		CloverSlot.Symbol.BLOOM:
			return PhaseBProgression.PathId.BLOOM
		CloverSlot.Symbol.BRAMBLE:
			return PhaseBProgression.PathId.BRAMBLE
		CloverSlot.Symbol.PRUNING:
			return PhaseBProgression.PathId.PRUNING
		CloverSlot.Symbol.THISTLE:
			return PhaseBProgression.PathId.THISTLE
		CloverSlot.Symbol.VINE:
			return PhaseBProgression.PathId.VINE
		CloverSlot.Symbol.FRUIT:
			return PhaseBProgression.PathId.FRUIT
		_:
			return -1


func _on_all_in_wiped() -> void:
	all_in_grace.begin()


func _on_all_in_ruined() -> void:
	# No grace, no rescue threshold. All In Bust is the one result in the machine that
	# ends the run on its own.
	_finish_run(false, "All In came up Bust: the whole field turned hostile.")


func _on_all_in_grace_started(duration: float) -> void:
	_show_banner("ALL IN")
	_set_status(
		"Everything is gone. Reclaim %d%% of the board within %.1f seconds." % [
			roundi(all_in_grace.recovery_threshold * 100.0),
			duration,
		]
	)
	_advance_all_in_countdown()


func _on_all_in_grace_recovered(seconds_remaining: float) -> void:
	if all_in_label != null:
		all_in_label.visible = false
	# Nothing is granted for surviving. The reward for a rescue is the run continuing.
	_set_status("Reclaimed with %.1f seconds to spare." % seconds_remaining)


func _on_all_in_grace_failed() -> void:
	if all_in_label != null:
		all_in_label.visible = false
	_finish_run(false, "All In: the organism could not be rebuilt in three seconds.")


func _advance_all_in_countdown() -> void:
	if all_in_label == null:
		return
	# Written whether or not the grace is running, and only then shown or hidden: a
	# countdown that is written for the first time as it appears spends the run
	# holding its unfilled template, ready to be seen by anything that reveals it.
	all_in_label.visible = all_in_grace.is_active()
	# Tenths, continuously, and the same number the deadline behind it is counting. A
	# countdown that disagrees with the rule it represents is worse than no countdown.
	_authored.write(all_in_label, {
		"seconds": "%.1f" % all_in_grace.get_remaining_seconds(),
		"reclaim": roundi(all_in_grace.recovery_threshold * 100.0),
	})


func _apply_progression_modifiers() -> void:
	if not is_instance_valid(territory_field) or not is_instance_valid(combat):
		return
	territory_field.tuning.natural_spread_rate = (
		_base_natural_spread_rate * progression.get_expansion_multiplier()
	)
	# Rapid Rooting rides in on the same multiplier the rest of the run's maturation
	# uses, so establishment has one place it is decided rather than two.
	root_director.apply_modifiers(
		progression.get_maturation_multiplier()
	)
	territory_field.tuning.maturity_resistance_bonus = (
		_base_maturity_resistance_bonus * progression.get_resistance_multiplier()
	)
	# Cane has no universal upgrade lines. Vine's four lines are pushed by the
	# AdaptationDirector after this baseline reset once that path is active.
	combat.set_cane_modifiers(1.0, 1.0, 1.0, 0.0)
	adaptation_director.apply_modifiers()
	bramble_director.apply_modifiers(root_director.get_network_bonus())
	# Sporulation runs for any active Spore run, at the base rate, with the line on
	# top of it: the same shape as Bramble's coverage and its Ensnare Rate line.
	combat.set_sporulation_modifiers(
		progression.has_path_active(PhaseBProgression.PathId.SPORE),
		spore_director.get_sporulation_rate_multiplier()
	)
	var evolution_rank := progression.get_evolution_upgrade_level()
	combat.set_evolution_upgrade_modifiers(
		evolutions.briar_payload_trigger_bonus if evolution_rank >= 2 else 0.0,
		evolutions.briar_payload_chain_bonus if evolution_rank >= 4 else 0.0,
		evolutions.briar_payload_entanglement if evolution_rank >= 3 else 0.0,
		evolutions.briar_payload_heart_cadence if evolution_rank >= 5 else 0,
		evolutions.ancient_fury_radius_bonus if evolution_rank >= 1 else 0.0,
		evolutions.ancient_fury_entanglement if evolution_rank >= 2 else 0.0,
		evolutions.ancient_fury_chain_damage_share,
		evolution_rank >= 3,
		(
			evolutions.ancient_fury_trigger_threshold
			if evolution_rank >= 4
			else 1.0
		),
		evolutions.ancient_fury_awakening_enemies if evolution_rank >= 5 else 0,
		evolutions.ancient_fury_awakening_eruptions if evolution_rank >= 5 else 0,
		evolutions.ancient_fury_awakening_cooldown
	)
	combat.set_mass_entanglement_shares(
		evolutions.tangleburst_elite_share,
		evolutions.tangleburst_boss_share
	)
	territory_field.set_old_growth_enabled(
		progression.has_active_evolution(PhaseBProgression.EvolutionId.OLD_GROWTH)
	)
	# Metabolism and Root both change what the material is, so both are folded into
	# the same field parameters here rather than each writing the field directly.
	territory_field.set_cohesion_multiplier(
		metabolism.get_cohesion_multiplier()
		* root_director.get_cohesion_multiplier()
	)
	# Mass, as the bulk driving force in the field's critical-radius test. A Mass
	# build lowers the radius an isolated patch has to reach to survive, so its
	# scatter starts taking root instead of dissolving.
	territory_field.set_nucleation_driving_multiplier(metabolism.get_mass_multiplier())
	territory_field.tuning.pressure_advection = clampf(
		_base_pressure_advection
		* metabolism.get_advection_multiplier()
		* root_director.get_pressure_transmission_multiplier(),
		0.0,
		1.0
	)
	territory_field.tuning.small_fragment_decay_per_second = (
		_base_small_fragment_decay
		* metabolism.get_fragment_decay_multiplier()
		* root_director.get_fragment_decay_multiplier()
	)
	_update_hud()


func _on_colony_isolated(_component_id: int, biomass: float, centroid: Vector2) -> void:
	overlay.spawn_sever_pulse(centroid)
	_set_status(
		"Root network severed: a colony is holding %.0f Biomass on its own."
		% biomass
	)


func _on_colony_reconnected(_component_id: int, biomass: float, centroid: Vector2) -> void:
	overlay.spawn_reconnection_pulse(centroid)
	_set_status(
		"Root network rejoined: %.0f Biomass is back in the main organism."
		% biomass
	)


func _on_boss_erupted(local_position: Vector2) -> void:
	overlay.spawn_hostile_pulse(local_position, eruption_pulse_radius_pixels)
	_set_status("Burrower eruption: nearby Green is being stripped away.")


func _on_health_changed(current: float, maximum: float) -> void:
	if not is_node_ready():
		return
	health_bar.max_value = maximum
	health_bar.value = current
	_authored.write(health_label, {
		"current": roundi(current),
		"maximum": roundi(maximum),
	})


func _on_player_died() -> void:
	_finish_run(false, "The Gardener fell beneath the hostile swarm.")


func _on_xp_changed(level: int, current_xp: int, required_xp: int) -> void:
	if not is_node_ready():
		return
	xp_bar.max_value = required_xp
	xp_bar.value = current_xp
	_authored.write(xp_label, {
		"level": level,
		"xp": current_xp,
		"need": required_xp,
	})


func _format_compact(value: float) -> String:
	# Fixed shapes so a growing economy never changes the width of its own column.
	var magnitude := absf(value)
	if magnitude >= 1000000.0:
		return "%.2fM" % (value / 1000000.0)
	if magnitude >= 10000.0:
		return "%.1fK" % (value / 1000.0)
	if magnitude >= 1000.0:
		return "%s" % _with_thousands_separator(int(round(value)))
	return "%d" % int(round(value))


func _with_thousands_separator(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	var count := 0
	for index in range(digits.length() - 1, -1, -1):
		grouped = digits[index] + grouped
		count += 1
		if count % 3 == 0 and index > 0:
			grouped = "," + grouped
	return ("-" if value < 0 else "") + grouped


func _on_evolution_changed(_status: int) -> void:
	_update_hud()


func _on_territory_metrics_changed(
	player_percent: float,
	_hostile_percent: float,
	_neutral_percent: float,
	_mature_player_percent: float,
	_fragment_count: int
) -> void:
	if not is_node_ready():
		return
	territory_bar.value = player_percent
	_authored.write(territory_label, {"green": "%.1f" % player_percent})


func _finish_run(victory: bool, detail: String) -> void:
	if _run_state != RunState.RUNNING:
		return
	_run_state = RunState.VICTORY if victory else RunState.DEFEAT
	_refresh_simulation_pause()
	result_header.text = result_victory_header if victory else result_defeat_header
	result_header.modulate = Color("b2cb82") if victory else Color("a45f6c")
	result_detail.text = AuthoredText.render(result_detail_template, {
		"detail": detail,
		"time": _format_time(get_elapsed_seconds()),
		"level": progression.current_level,
		"green": "%.1f" % territory_field.get_player_percent(),
	})
	result_panel.visible = true


func _refresh_dev_controls() -> void:
	# Guarded because an exported setter runs while the scene is still being built, long
	# before the label it wants to hide has been resolved.
	if not is_node_ready() or debug_help_label == null:
		return
	debug_help_label.visible = dev_controls_enabled


func is_pause_menu_open() -> bool:
	return _pause_menu_open


func _build_mechanics_help() -> void:
	_mechanics_help = PhaseBMechanicsHelp.new()
	interface_layer.add_child(_mechanics_help)
	_mechanics_help.glossary_closed.connect(_on_glossary_closed)
	# The dimmer is visual only. Leaving it out of hit testing keeps the visible
	# Adaptation and relic slots inspectable while simulation is paused.
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pause_dim := pause_overlay.get_node_or_null("Dim") as Control
	if pause_dim != null:
		pause_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glossary_button = pause_glossary_button
	for reward_button in choice_buttons:
		reward_button.mouse_entered.connect(_on_reward_hovered.bind(reward_button))
	for row in [relic_slots, upgrade_slots, _secondary_upgrade_slots, _evolution_upgrade_slot, _support_upgrade_slots]:
		if row == null:
			continue
		row.slot_hovered.connect(_on_hud_slot_hovered.bind(row))
		row.slot_unhovered.connect(_mechanics_help.source_exited)


func _on_reward_hovered(button: Button) -> void:
	if _choice_kind == ChoiceKind.NONE or not button.visible:
		return
	var panel_rect := choice_panel.get_global_rect()
	var anchor := Rect2(panel_rect.end.x, button.get_global_rect().position.y, 0.0, 0.0)
	_mechanics_help.show_reward_tooltips(button.text, anchor)


func _on_hud_slot_hovered(index: int, row: PhaseBUpgradeSlots) -> void:
	var description := row.get_slot_tooltip(index)
	if description.is_empty():
		return
	var title := description.get_slice("\n", 0).strip_edges()
	_mechanics_help.show_hud_tooltip(
		title, _tooltip_body(description, title), row.get_slot_global_rect(index)
	)


func _tooltip_body(value: String, title: String) -> String:
	var body := value.strip_edges()
	if body.begins_with(title):
		body = body.trim_prefix(title).strip_edges()
	return body


func _open_glossary() -> void:
	pause_panel.visible = false
	pause_settings_panel.visible = false
	_mechanics_help.open_glossary()


func _close_glossary() -> void:
	_mechanics_help.close_glossary()


func _on_glossary_closed() -> void:
	if _pause_menu_open:
		pause_panel.visible = true


func _show_pause_settings(open: bool) -> void:
	_pause_settings_open = open
	if pause_panel != null:
		pause_panel.visible = not open
	if pause_settings_panel != null:
		pause_settings_panel.visible = open
	if _mechanics_help != null and _mechanics_help.is_glossary_open():
		_mechanics_help.close_glossary()
	if open:
		_update_setting_buttons()
	_refresh_focus_ring()


func _open_pause_menu() -> void:
	if _pause_menu_open or _choice_kind != ChoiceKind.NONE:
		return
	_pause_menu_open = true
	pause_overlay.visible = true
	# Always opens on the menu itself. A player who left settings open last time is
	# pausing now because something is happening, not to read options again.
	_show_pause_settings(false)
	_update_fullscreen_button()
	_refresh_simulation_pause()
	# Focus is only taken for a controller. A mouse player gets no ring to explain.
	_refresh_focus_ring()


func _note_input_device(event: InputEvent) -> void:
	# The device that produced the last event decides whether the ring is shown. A
	# pad shows it; touching the mouse or the keyboard takes it away again.
	var controller := false
	if event is InputEventJoypadButton and event.pressed:
		controller = true
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		controller = absf(motion.axis_value) >= controller_stick_deadzone
	elif (
		event is InputEventMouseMotion
		or event is InputEventMouseButton
		or event is InputEventKey
	):
		controller = false
	else:
		return
	if controller == _controller_active:
		return
	_controller_active = controller
	_refresh_focus_ring()


func _refresh_focus_ring() -> void:
	if _controller_active:
		if _pause_menu_open and pause_resume_button != null:
			pause_resume_button.grab_focus()
		return
	# Nothing focused means nothing draws a focus ring, which is the whole fix: the
	# box was Godot telling a mouse player where the controller cursor is.
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()


func is_controller_active() -> bool:
	return _controller_active


func _close_pause_menu() -> void:
	if not _pause_menu_open:
		return
	_pause_menu_open = false
	pause_overlay.visible = false
	_refresh_simulation_pause()


func _quit_from_pause_menu() -> void:
	get_tree().quit()


func _configure_ambient_music() -> void:
	var wav_stream := ambient_music_audio.stream as AudioStreamWAV
	var repaired_loop_bounds := false
	if wav_stream != null:
		var full_stream_sample_count := roundi(wav_stream.get_length() * wav_stream.mix_rate)
		if wav_stream.loop_begin != 0 or wav_stream.loop_end <= wav_stream.loop_begin:
			wav_stream.loop_begin = 0
			wav_stream.loop_end = full_stream_sample_count
			repaired_loop_bounds = true
		if wav_stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			repaired_loop_bounds = true
	if repaired_loop_bounds:
		ambient_music_audio.stop()
	call_deferred("_ensure_ambient_music_playing")


func _ensure_ambient_music_playing() -> void:
	if ambient_music_audio.stream != null and not ambient_music_audio.playing:
		ambient_music_audio.play()


func _configure_volume_control() -> void:
	_sfx_bus_index = AudioServer.get_bus_index(audio_settings.sfx_bus_name)
	if _sfx_bus_index < 0:
		pause_volume_slider.set_value_no_signal(0.0)
		pause_volume_value.text = volume_unavailable_text
	else:
		var sfx_linear_volume := 0.0
		if not AudioServer.is_bus_mute(_sfx_bus_index):
			sfx_linear_volume = db_to_linear(AudioServer.get_bus_volume_db(_sfx_bus_index))
		# The saved choice wins over whatever the bus happens to sit at, so a volume
		# set on the home screen is still in force once the run loads.
		var saved_sfx := PhaseBDisplaySettings.load_volume("sfx", -1.0)
		if saved_sfx >= 0.0:
			sfx_linear_volume = saved_sfx * audio_settings.sfx_max_linear_volume
			_apply_bus_volume(_sfx_bus_index, sfx_linear_volume)
		pause_volume_slider.set_value_no_signal(
			clampf(
				sfx_linear_volume / maxf(audio_settings.sfx_max_linear_volume, 0.0001),
				0.0,
				1.0
			) * 100.0
		)
		_update_volume_label()

	_music_bus_index = AudioServer.get_bus_index(audio_settings.music_bus_name)
	if _music_bus_index < 0:
		pause_music_volume_slider.set_value_no_signal(0.0)
		pause_music_volume_value.text = volume_unavailable_text
	else:
		var music_linear_volume := 0.0
		if not AudioServer.is_bus_mute(_music_bus_index):
			music_linear_volume = db_to_linear(AudioServer.get_bus_volume_db(_music_bus_index))
		var saved_music := PhaseBDisplaySettings.load_volume("music", -1.0)
		if saved_music >= 0.0:
			music_linear_volume = saved_music * audio_settings.music_max_linear_volume
			_apply_bus_volume(_music_bus_index, music_linear_volume)
		pause_music_volume_slider.set_value_no_signal(
			clampf(
				music_linear_volume / maxf(
					audio_settings.music_max_linear_volume,
					0.0001
				),
				0.0,
				1.0
			) * 100.0
		)
		_update_music_volume_label()


func _on_sfx_volume_changed(value: float) -> void:
	if _sfx_bus_index < 0:
		return
	var linear_volume := (
		clampf(value / 100.0, 0.0, 1.0)
		* audio_settings.sfx_max_linear_volume
	)
	var muted := linear_volume <= 0.0001
	AudioServer.set_bus_mute(_sfx_bus_index, muted)
	if not muted:
		AudioServer.set_bus_volume_db(_sfx_bus_index, linear_to_db(linear_volume))
	_update_volume_label()
	PhaseBDisplaySettings.save_volume("sfx", clampf(value / 100.0, 0.0, 1.0))


func _play_slot_sfx(voice: AudioStreamPlayer) -> void:
	# Every slot-machine sound goes out the same door. The players sit on the SFX bus,
	# which is where the run's 20% output cap lives, so none of them can be louder than
	# the rest of the game's effects however the stream itself was recorded.
	if voice == null or voice.stream == null:
		return
	voice.play()


func _apply_bus_volume(bus_index: int, linear_volume: float) -> void:
	if bus_index < 0:
		return
	var muted := linear_volume <= 0.0001
	AudioServer.set_bus_mute(bus_index, muted)
	if not muted:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear_volume))


func _update_volume_label() -> void:
	_authored.write(
		pause_volume_value,
		{"percent": roundi(pause_volume_slider.value)},
	)


func _on_music_volume_changed(value: float) -> void:
	if _music_bus_index < 0:
		return
	var linear_volume := (
		clampf(value / 100.0, 0.0, 1.0)
		* audio_settings.music_max_linear_volume
	)
	var muted := linear_volume <= 0.0001
	AudioServer.set_bus_mute(_music_bus_index, muted)
	if not muted:
		AudioServer.set_bus_volume_db(_music_bus_index, linear_to_db(linear_volume))
	_update_music_volume_label()
	PhaseBDisplaySettings.save_volume("music", clampf(value / 100.0, 0.0, 1.0))


func _update_music_volume_label() -> void:
	_authored.write(
		pause_music_volume_value,
		{"percent": roundi(pause_music_volume_slider.value)},
	)


func _toggle_fullscreen() -> void:
	var enter_fullscreen := not _is_fullscreen()
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN
		if enter_fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if enter_fullscreen:
		pause_fullscreen_button.text = fullscreen_exit_text
	else:
		_authored.write(pause_fullscreen_button)
	call_deferred("_update_fullscreen_button")


func _update_fullscreen_button() -> void:
	if _is_fullscreen():
		pause_fullscreen_button.text = fullscreen_exit_text
	else:
		_authored.write(pause_fullscreen_button)


func _is_fullscreen() -> bool:
	var window_mode := DisplayServer.window_get_mode()
	return (
		window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or window_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)


func _refresh_simulation_pause() -> void:
	_set_simulation_paused(
		_pause_menu_open
		or _choice_kind != ChoiceKind.NONE
		or _run_state != RunState.RUNNING
	)


func _set_simulation_paused(paused: bool) -> void:
	territory_field.simulation_paused = paused
	overlay.effects_paused = paused
	player.set_simulation_paused(paused)
	combat.set_simulation_paused(paused)
	adaptation_director.set_simulation_paused(paused)


func _update_hud() -> void:
	# The printed odds move with the drought counter and the Bust cooldown, so they are
	# refreshed on the HUD's own clock rather than only when the player touches the
	# machine and discovers the number has been stale for a minute.
	_update_slot_controls()
	if not is_node_ready():
		return
	var remaining := maxf(
		0.0,
		wave_director.run_duration_seconds - get_elapsed_seconds()
	)
	var wave_values := {
		"wave": get_current_wave_number(),
		"seconds": "%02d" % ceili(get_wave_grace_remaining_seconds()),
	}
	var clock_values := {
		"clock": _format_time(remaining),
		"mass": metabolism.get_level(PhaseBMetabolism.SystemId.PHOTOSYNTHESIS),
		"push": metabolism.get_level(PhaseBMetabolism.SystemId.MERISTEM),
		"hold": metabolism.get_level(PhaseBMetabolism.SystemId.CAMBIUM),
	}
	var clock_template := _authored.template(clock_label)
	if wave_director.is_complete():
		# No clock left to report: what remains between the player and victory is the
		# hostiles still standing.
		clock_template = clock_complete_text
	elif display_settings.is_hud_detailed():
		# Detailed reveals more of the same line rather than adding a second one: the
		# doc rules out a separate design, so what changes is how much this says.
		clock_template = clock_detailed_template
	# Absence communicates zero: the hostile count is a warning, so it appears only
	# while there is something to warn about.
	var hostiles := combat.get_active_enemy_count()
	# One node each, placed by the scene. They shared a label until the gap between
	# them was a run of spaces inside a format string, which meant neither could be
	# moved, coloured, or sized without editing code and counting spaces.
	if is_wave_grace_period_active():
		_authored.write_variant(wave_label, wave_grace_template, wave_values)
	else:
		_authored.write(wave_label, wave_values)
	_authored.write_variant(clock_label, clock_template, clock_values)
	# Its own node, so it can be placed and seen in the editor rather than being
	# concatenated onto a line that has no room for it. The text is always written
	# and only the visibility is switched, so what the scene declares is the shape
	# it always carries.
	_authored.write(hostile_label, {"hostiles": hostiles})
	hostile_label.visible = hostiles > 0
	var threshold := spore_director.get_seed_kill_threshold()
	_authored.write(
		territory_label,
		{"kills": spore_director.get_kills_toward_seed(), "needed": threshold},
		"Seed progress: {kills} / {needed} kills",
		"tooltip_text",
	)
	match progression.evolution_status:
		PhaseBProgression.EvolutionStatus.READY:
			# What a pairing becomes is the discovery, so it is not printed here
			# before the player has ever seen it. The colour shift is the whole of
			# the signal, the same way it is once the run has evolved.
			evolution_label.text = ""
			evolution_label.modulate = Color("b2cb82")
		PhaseBProgression.EvolutionStatus.EVOLVED:
			# The evolution line was emptied when the sidebar was decluttered: what the
			# run evolved into is already read out by the growth-line row underneath,
			# and saying it twice was most of what made the panel noisy. The colour is
			# kept because it is the only remaining signal that the pairing landed.
			evolution_label.text = ""
			evolution_label.modulate = Color("77ffd0")
		_:
			# Nothing worth announcing until a pairing is actually in reach.
			evolution_label.text = ""
			evolution_label.modulate = Color("93aab0")
	# The relics heading is a fixed word the scene owns; the run's Paths are read
	# from the slots beneath it rather than from this line.
	_advance_all_in_countdown()
	_update_relic_slots()
	_authored.write(slots_label, {
		"filled": progression.get_slotted_upgrades().size(),
		"total": progression.get_upgrade_slot_count(),
	})
	_update_upgrade_slots()



func _update_relic_slots() -> void:
	if relic_slots == null:
		return
	# The pool is far larger than the row, so the row shows what the run actually
	# holds, in the order it was taken, with the trigger counter a relic needs to
	# be readable on the slot itself.
	var held := PackedInt32Array()
	for relic_id in range(PhaseBRelicCatalog.get_count()):
		if progression.has_relic(relic_id):
			held.append(relic_id)
	# One empty socket beyond what the run holds: enough to say more are coming,
	# without a permanent row of placeholders for relics it may never take.
	relic_slots.slot_count = clampi(held.size() + 1, 1, _maximum_relic_slots)
	# The empty slot names where the next relic comes from, so the authored wave
	# cadence is what the tooltip reports rather than a number written twice.
	var empty_hint := "Empty relic slot.\nDefeat an elite or the boss to choose a relic."
	if relic_reward_wave_cycle > 0:
		empty_hint = (
			"Empty relic slot.\nEvery %d waves, the elite, and the boss each offer one."
			% relic_reward_wave_cycle
		)
	for index in range(relic_slots.get_slot_count()):
		if index >= held.size():
			relic_slots.set_slot(
				index,
				relic_slots.empty_marker,
				"",
				empty_hint,
				PhaseBUpgradeSlots.SlotState.EMPTY
			)
			continue
		var relic_id := held[index]
		var relic_name := PhaseBProgression.get_relic_name(relic_id)
		var rarity := PhaseBRelicCatalog.get_rarity(relic_id)
		var tooltip := "%s   %s\n%s" % [
			relic_name,
			PhaseBRelicCatalog.get_rarity_name(rarity),
			progression.get_relic_description(relic_id),
		]
		var counter := relic_director.get_relic_counter_text(relic_id)
		if not counter.is_empty():
			tooltip += "\nProgress: %s" % counter
		relic_slots.set_slot(
			index,
			_get_initials(relic_name),
			counter,
			tooltip,
			PhaseBUpgradeSlots.SlotState.FILLED,
			# Rarity on the slot itself, so the row reads as a collection at a glance
			# rather than only under the pointer. Colour is never the only signal: the
			# tooltip still names the rarity in words, which is the same rule the reel
			# faces and the Bust symbol follow.
			PhaseBRelicCatalog.get_rarity_color(rarity)
		)


func _get_initials(source: String) -> String:
	# Two letters taken from an authored name, so a slot reads at a glance and
	# never needs a second name kept in sync with it.
	var words := source.split(" ", false)
	if words.size() >= 2:
		return (words[0].substr(0, 1) + words[1].substr(0, 1)).to_upper()
	if words.size() == 1:
		return words[0].substr(0, 2).to_upper()
	return "--"


func _update_upgrade_slots() -> void:
	if upgrade_slots == null:
		return
	var has_line_space := (
		progression.get_slotted_upgrades().size() < progression.get_upgrade_slot_count()
	)
	_update_path_upgrade_row(
		upgrade_slots,
		_path_one_label,
		_path_one_emblem,
		_path_one_emblem_icon,
		progression.primary_path,
		"PATH 1",
		has_line_space
	)
	_update_path_upgrade_row(
		_secondary_upgrade_slots,
		_path_two_label,
		_path_two_emblem,
		_path_two_emblem_icon,
		progression.secondary_path,
		"PATH 2",
		has_line_space
	)
	_update_evolution_tree_slot()
	_update_support_upgrade_row(has_line_space)


func _update_path_upgrade_row(
	row: PhaseBUpgradeSlots,
	path_label: Label,
	emblem: Label,
	emblem_icon: TextureRect,
	path_id: int,
	fallback_label: String,
	has_line_space: bool
) -> void:
	row.slot_count = 4
	var selected := path_id != PhaseBProgression.UNSELECTED_PATH
	path_label.text = (
		PhaseBProgression.get_path_name(path_id).to_upper()
		if selected
		else fallback_label
	)
	var accent := _get_path_hud_color(path_id) if selected else Color("596052")
	_set_path_emblem(emblem, emblem_icon, path_id, selected, accent)
	var path_upgrades := _get_path_upgrade_ids(path_id) if selected else PackedInt32Array()
	for index in range(4):
		if not selected or index >= path_upgrades.size():
			_set_locked_tree_slot(row, index, "Choose this Path to reveal its upgrade lines.")
			continue
		var upgrade_id := path_upgrades[index]
		var level := progression.get_owned_upgrade_level(upgrade_id)
		if level > 0:
			row.set_slot(
				index,
				_get_upgrade_abbreviation(upgrade_id),
				"%d" % level,
				_build_upgrade_tooltip(upgrade_id),
				PhaseBUpgradeSlots.SlotState.FILLED,
				accent
			)
		elif has_line_space:
			row.set_slot(
				index,
				row.empty_marker,
				"",
				"%s\nAvailable on an upgrade draft." % PhaseBProgression.get_upgrade_name(upgrade_id),
				PhaseBUpgradeSlots.SlotState.EMPTY,
				accent
			)
		else:
			_set_locked_tree_slot(
				row,
				index,
				"%s\nAll current growth-line slots are occupied." % PhaseBProgression.get_upgrade_name(upgrade_id)
			)


func _update_evolution_tree_slot() -> void:
	_evolution_upgrade_slot.slot_count = 1
	match progression.evolution_status:
		PhaseBProgression.EvolutionStatus.EVOLVED:
			var evolution_name := PhaseBEvolutions.get_evolution_name(progression.active_evolution)
			var upgrade_id := PhaseBEvolutions.get_evolution_upgrade_id(progression.active_evolution)
			_evolution_tree_label.text = evolution_name
			_evolution_upgrade_slot.set_slot(
				0,
				_get_initials(evolution_name),
				"%d" % progression.get_evolution_upgrade_level(),
				_build_upgrade_tooltip(upgrade_id),
				PhaseBUpgradeSlots.SlotState.FILLED,
				Color("d4a94f")
			)
		PhaseBProgression.EvolutionStatus.READY:
			# Named only once it has been claimed. Until then the slot says what it
			# is for and nothing about what is waiting in it.
			_evolution_tree_label.text = "EVOLUTION"
			_evolution_upgrade_slot.set_slot(
				0,
				_evolution_upgrade_slot.empty_marker,
				"",
				"This pairing has not evolved yet.",
				PhaseBUpgradeSlots.SlotState.EMPTY,
				Color("d4a94f")
			)
		_:
			_evolution_tree_label.text = "EVOLUTION"
			_set_locked_tree_slot(
				_evolution_upgrade_slot,
				0,
				"Evolution is locked until one line from each selected Path reaches maximum rank."
			)


func _update_support_upgrade_row(has_line_space: bool) -> void:
	var evolved := progression.evolution_status == PhaseBProgression.EvolutionStatus.EVOLVED
	_support_path_emblem.visible = false
	_support_path_emblem_icon.visible = false
	_support_path_emblem_lock.visible = not evolved
	if not evolved:
		_update_path_upgrade_row(
			_support_upgrade_slots,
			_support_path_label,
			_support_path_emblem,
			_support_path_emblem_icon,
			PhaseBProgression.UNSELECTED_PATH,
			"SUPPORT PATH",
			false
		)
		_support_path_emblem.visible = false
		_support_path_emblem_icon.visible = false
		return
	if not progression.has_tertiary_path():
		_support_path_label.text = "CHOOSE SUPPORT"
		_support_path_emblem.visible = true
		_support_path_emblem_icon.visible = false
		_support_path_emblem.text = "+"
		_support_path_emblem.modulate = Color("d4a94f")
		_support_upgrade_slots.slot_count = 4
		for index in range(4):
			_support_upgrade_slots.set_slot(
				index,
				_support_upgrade_slots.empty_marker,
				"",
				"Claim a support Path to reveal this upgrade line.",
				PhaseBUpgradeSlots.SlotState.EMPTY,
				Color("d4a94f")
			)
		return
	_update_path_upgrade_row(
		_support_upgrade_slots,
		_support_path_label,
		_support_path_emblem,
		_support_path_emblem_icon,
		progression.tertiary_path,
		"SUPPORT PATH",
		has_line_space
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
		PhaseBProgression.PathId.SPORE:
			return ADAPTATION_ICON_SPORE
		PhaseBProgression.PathId.BLOOM:
			return ADAPTATION_ICON_BLOOM
		PhaseBProgression.PathId.BRAMBLE:
			return ADAPTATION_ICON_BRAMBLE
		PhaseBProgression.PathId.ROOT:
			return ADAPTATION_ICON_ROOT
		PhaseBProgression.PathId.PRUNING:
			return ADAPTATION_ICON_PRUNING
		PhaseBProgression.PathId.THISTLE:
			return ADAPTATION_ICON_THISTLE
		PhaseBProgression.PathId.VINE:
			return ADAPTATION_ICON_VINE
		PhaseBProgression.PathId.FRUIT:
			return ADAPTATION_ICON_FRUIT
	return null


func _get_path_emblem_tint(path_id: int, accent: Color) -> Color:
	# Bloom and Fruit already carry their authored colour. The remaining source
	# art is white/off-white and takes on the path colour here without duplicating
	# recoloured raster files.
	if path_id in [PhaseBProgression.PathId.BLOOM, PhaseBProgression.PathId.FRUIT]:
		return Color.WHITE
	return accent.lightened(0.22)


func _set_locked_tree_slot(row: PhaseBUpgradeSlots, index: int, tooltip: String) -> void:
	row.set_slot(
		index,
		"",
		"",
		tooltip,
		PhaseBUpgradeSlots.SlotState.LOCKED
	)


func _get_path_upgrade_ids(path_id: int) -> PackedInt32Array:
	var ids := PackedInt32Array()
	if path_id == PhaseBProgression.UNSELECTED_PATH:
		return ids
	for upgrade_id in range(PhaseBProgression.UpgradeId.size()):
		if progression._get_upgrade_path(upgrade_id) == path_id:
			ids.append(upgrade_id)
	return ids


func _get_path_hud_color(path_id: int) -> Color:
	match path_id:
		PhaseBProgression.PathId.SPORE:
			return Color("68a96a")
		PhaseBProgression.PathId.BLOOM:
			return Color("9b68b5")
		PhaseBProgression.PathId.BRAMBLE:
			return Color("798f45")
		PhaseBProgression.PathId.ROOT:
			return Color("b18449")
		PhaseBProgression.PathId.PRUNING:
			return Color("b66255")
		PhaseBProgression.PathId.THISTLE:
			return Color("a76ca8")
		PhaseBProgression.PathId.VINE:
			return Color("4f9c76")
		PhaseBProgression.PathId.FRUIT:
			return Color("c17d45")
	return Color("596052")


func _get_upgrade_abbreviation(upgrade_id: int) -> String:
	return _get_initials(PhaseBProgression.get_upgrade_name(upgrade_id))


func _build_upgrade_tooltip(upgrade_id: int) -> String:
	# What the line is, what one more rank buys, and what the run's numbers
	# actually resolve to right now.
	var level := progression.get_owned_upgrade_level(upgrade_id)
	var maximum := progression.get_upgrade_maximum_level(upgrade_id)
	var lines := PackedStringArray()
	lines.append("%s   %d/%d" % [
		PhaseBProgression.get_upgrade_name(upgrade_id),
		level,
		maximum,
	])
	# An Evolution line's ranks each do something different, so the hover carries
	# every rank the run has bought rather than one averaged line. This is the only
	# place the player can read the finished build back, and it is empty for the
	# ordinary lines, whose ranks are all the same thing again.
	var owned := _get_evolution_owned_ranks(upgrade_id)
	for owned_rank in owned:
		lines.append(owned_rank)
	var per_rank := progression.get_upgrade_description(upgrade_id)
	if not per_rank.is_empty():
		var rank_label := "Next rank" if level < maximum else "Maxed"
		lines.append("%s: %s" % [rank_label, per_rank])
	if owned.is_empty():
		# For an Evolution line the last owned rank above already says this, and the
		# hover should not print it twice.
		var resolved := _get_upgrade_resolved_effect(upgrade_id)
		if not resolved.is_empty():
			lines.append("Now: %s" % resolved)
	# The Root Network row sits under the base number rather than replacing it, so
	# the hover shows what the line is worth on its own and what Mature ground turns
	# that into, in that order.
	var rooted := _get_root_potency_note(upgrade_id)
	if not rooted.is_empty():
		lines.append(rooted)
	return "\n".join(lines)


func _get_evolution_owned_ranks(upgrade_id: int) -> PackedStringArray:
	# Every Evolution rank the run has actually bought, in the order it bought them.
	# Owned rather than effective level: a Clover jackpot lends a Path its ceiling for
	# a few seconds, and the hover must not claim the run holds ranks it never took.
	var owned := PackedStringArray()
	if PhaseBEvolutions.get_upgrade_evolution(upgrade_id) == PhaseBProgression.EvolutionId.NONE:
		return owned
	var level := progression.get_owned_upgrade_level(upgrade_id)
	for rank in range(1, level + 1):
		var description := evolutions.get_evolution_upgrade_rank_description(upgrade_id, rank)
		if description.is_empty():
			continue
		owned.append("%d. %s" % [rank, description])
	return owned


func _get_upgrade_resolved_effect(upgrade_id: int) -> String:
	# The finished numbers, read from the same values the systems use, so the hover
	# text can never drift from what the run is actually doing.
	match upgrade_id:
		PhaseBProgression.UpgradeId.SEED_PRODUCTION:
			return "%d kills per Seed" % spore_director.get_seed_kill_threshold()
		PhaseBProgression.UpgradeId.GROWTH_MASS:
			return "%d%% Seed growth mass" % roundi(
				spore_director.get_seed_mass_multiplier() * 100.0
			)
		PhaseBProgression.UpgradeId.SPORULATION:
			var spore_rate := (
				combat.sporulation_per_second
				* spore_director.get_sporulation_rate_multiplier()
			)
			return "%.2f%% Spore per second, Overgrown after %.0fs on Green" % [
				spore_rate * 100.0,
				1.0 / maxf(0.0001, spore_rate),
			]
		PhaseBProgression.UpgradeId.FRUITING_BODIES:
			return "%d%% of germinations inside your Green raise a colony" % roundi(
				spore_director.get_fruiting_body_chance() * 100.0
			)
		PhaseBProgression.UpgradeId.BLOOM_FORCE:
			return "%d%% Bloom force, %.0f Bloom damage" % [
				roundi(bloom_director.get_bloom_force_multiplier() * 100.0),
				bloom_director.bloom_damage * bloom_director.get_bloom_force_multiplier(),
			]
		PhaseBProgression.UpgradeId.BLOOM_FREQUENCY:
			return "a Bloom every %.1fs" % (
				bloom_director.bloom_interval_seconds
				* bloom_director.get_bloom_interval_multiplier()
			)
		PhaseBProgression.UpgradeId.AFTERGROWTH:
			return "%d temporary control on Bloomed Green for %.0fs" % [
				roundi(bloom_director.get_aftergrowth_shield()),
				bloom_director.bloom_tempo_window_seconds,
			]
		PhaseBProgression.UpgradeId.SUPPRESSION:
			return "%d%% less Territory damage for %.0fs after a Bloom" % [
				roundi(bloom_director.get_suppression_share() * 100.0),
				bloom_director.bloom_tempo_window_seconds,
			]
		PhaseBProgression.UpgradeId.BRAMBLE_ENTANGLEMENT:
			return "up to %d%% slow when fully Entangled" % roundi(
				bramble_director.get_slow_fraction() * 100.0
			)
		PhaseBProgression.UpgradeId.BRAMBLE_ENSNARE_RATE:
			var rate := (
				combat.bramble_entanglement_per_second
				* bramble_director.get_ensnare_multiplier()
			)
			return "fully Entangled after %.1fs on Green" % (1.0 / maxf(0.01, rate))
		PhaseBProgression.UpgradeId.BRAMBLE_GRASPING_ROOTS:
			return "%.2fs root, then %.0fs immune" % [
				bramble_director.get_root_seconds(),
				bramble_director.get_root_immunity_seconds(),
			]
		PhaseBProgression.UpgradeId.BRAMBLE_REPULSION:
			return "%.0f px knockback on territory attackers" % (
				bramble_director.get_repulsion_pixels()
			)
		PhaseBProgression.UpgradeId.ROOT_MATURATION:
			return "%d%% maturation rate" % roundi(
				root_director.get_maturation_multiplier() * 100.0
			)
		PhaseBProgression.UpgradeId.ROOT_LATERAL_ROOTS:
			return "+%d px projected Root reach" % roundi(
				root_director.get_lateral_reach()
			)
		PhaseBProgression.UpgradeId.ROOT_MATURE_STRENGTH:
			return "%.2fx Mature resistance, +%.3f control per second" % [
				root_director.get_mature_resistance_multiplier(),
				root_director.get_regeneration_per_second(),
			]
		PhaseBProgression.UpgradeId.ROOT_POTENCY:
			return "+%d%% from fully Mature ground" % roundi(
				root_director.get_network_bonus() * 100.0
			)
		PhaseBProgression.UpgradeId.PRUNING_HARVEST_RATE:
			return "%.1f cells per second held, %.1f at full Charge" % [
				pruning_director.upkeep_cells_per_second
				* pruning_director.get_pruning_harvest_rate_multiplier(),
				pruning_director.upkeep_cells_per_second_at_charge
				* pruning_director.get_pruning_harvest_rate_multiplier(),
			]
		PhaseBProgression.UpgradeId.PRUNING_CUTTING_YIELD:
			return "%.2f Cuttings per cell harvested" % (
				pruning_director.cuttings_per_cell
				* pruning_director.get_pruning_cutting_yield_multiplier()
			)
		PhaseBProgression.UpgradeId.PRUNING_CUTTING_DAMAGE:
			return "%.0f thicket damage per bite, %.0f per launched Cutting" % [
				pruning_director.orbit_contact_damage
				* pruning_director.get_pruning_cutting_damage_multiplier(),
				pruning_director.cutting_damage
				* pruning_director.get_pruning_cutting_damage_multiplier(),
			]
		PhaseBProgression.UpgradeId.PRUNING_CHARGE:
			return "full Charge in %.1fs, +%d%% launch damage" % [
				pruning_director.get_charge_seconds(),
				roundi(pruning_director.get_launch_charge_damage_bonus() * 100.0),
			]
		PhaseBProgression.UpgradeId.THISTLE_CLUSTERING:
			return "%d thorns per normal turret firing event" % (
				1 + progression.get_upgrade_level(upgrade_id)
			)
		PhaseBProgression.UpgradeId.THISTLE_DEHISCENCE:
			var thistle_speed := 1.0 + 0.15 * float(progression.get_upgrade_level(upgrade_id))
			return "one turret firing event every %.3fs" % (
				adaptation_director.thistle_attack_interval / thistle_speed
			)
		PhaseBProgression.UpgradeId.THISTLE_BURR:
			return "%d full-damage ricochets per thorn" % (
				progression.get_upgrade_level(upgrade_id)
			)
		PhaseBProgression.UpgradeId.THISTLE_NEEDLEPOINT:
			return "%d%% critical chance per impact at %.0fx damage" % [
				roundi(10.0 * float(progression.get_upgrade_level(upgrade_id))),
				adaptation_director.thistle_critical_multiplier,
			]
		PhaseBProgression.UpgradeId.VINE_ELONGATION:
			return "%.0f px Vine reach" % combat.get_cane_reach()
		PhaseBProgression.UpgradeId.VINE_LIGNIFICATION:
			return "%.1f damage before Apical, Root, and relic modifiers" % (
				combat.cane_damage
				* (1.0 + 0.25 * float(progression.get_upgrade_level(upgrade_id)))
			)
		PhaseBProgression.UpgradeId.VINE_TURGOR:
			var vine_speed := 1.0 + 0.15 * float(progression.get_upgrade_level(upgrade_id))
			return "one automatic sweep every %.3fs before relic timing" % (
				combat.cane_cooldown_seconds / vine_speed
			)
		PhaseBProgression.UpgradeId.VINE_APICAL_DOMINANCE:
			return "%.2fx damage in the outer 25%% of reach" % (
				1.0 + 0.25 * float(progression.get_upgrade_level(upgrade_id))
			)
		PhaseBProgression.UpgradeId.FRUIT_SET:
			return "%d Fruit per normal release" % (
				1 + progression.get_upgrade_level(upgrade_id)
			)
		PhaseBProgression.UpgradeId.FRUIT_RIPENING:
			var ripening := 1.0 + 0.25 * float(progression.get_upgrade_level(upgrade_id))
			return "%.1f collision damage, up to %.1f terminal damage" % [
				adaptation_director.fruit_collision_damage * ripening,
				adaptation_director.fruit_terminal_explosion_damage * ripening,
			]
		PhaseBProgression.UpgradeId.FRUIT_MOMENTUM:
			return "%.0f px unobstructed stopping distance" % (
				adaptation_director.fruit_roll_distance_pixels
				* (1.0 + 0.20 * float(progression.get_upgrade_level(upgrade_id)))
			)
		PhaseBProgression.UpgradeId.FRUIT_GERMINATION:
			return "%d%% Fruit-created Green area" % roundi(
				(1.0 + 0.20 * float(progression.get_upgrade_level(upgrade_id))) * 100.0
			)
	if PhaseBEvolutions.get_upgrade_evolution(upgrade_id) != PhaseBProgression.EvolutionId.NONE:
		# An Evolution line's ranks each do something different, so what it is doing
		# now is the description of the rank the run has actually reached.
		var evolution_level := progression.get_upgrade_level(upgrade_id)
		if evolution_level <= 0:
			return ""
		return evolutions.get_evolution_upgrade_rank_description(
			upgrade_id,
			evolution_level
		)
	return ""


func _get_root_potency_note(upgrade_id: int) -> String:
	# The finished Root Network row for a line, or nothing at all. A run without Root
	# and every line the Network does not touch return empty, so the row appears only
	# where it is true rather than as a permanent piece of furniture.
	var effect := _get_root_potency_effect(upgrade_id)
	if effect.is_empty():
		return ""
	return AuthoredText.render(root_potency_note_template, {
		"multiplier": "%.2f" % (1.0 + root_director.get_network_bonus()),
		"effect": effect,
	})


func _get_root_potency_effect(upgrade_id: int) -> String:
	# What this line resolves to on fully Mature ground, read through the same
	# amplification the systems apply. Full maturity is the honest headline: it is
	# the ceiling the Network reaches, and every consumer scales down from it with
	# the age of the ground the effect actually happens on.
	if root_director == null:
		return ""
	var bonus := root_director.get_network_bonus()
	if bonus <= 0.0:
		return ""
	var multiplier := 1.0 + bonus
	match upgrade_id:
		PhaseBProgression.UpgradeId.SEED_PRODUCTION:
			return "Seeds germinate in %.2fs instead of %.2fs" % [
				territory_field.tuning.seed_charge_seconds / multiplier,
				territory_field.tuning.seed_charge_seconds,
			]
		PhaseBProgression.UpgradeId.GROWTH_MASS:
			return "%d%% Seed growth mass" % roundi(
				spore_director.get_seed_mass_multiplier() * multiplier * 100.0
			)
		PhaseBProgression.UpgradeId.SPORULATION:
			var rooted_spore := (
				combat.sporulation_per_second
				* spore_director.get_sporulation_rate_multiplier()
				* multiplier
			)
			return "%.2f%% Spore per second, Overgrown after %.0fs" % [
				rooted_spore * 100.0,
				1.0 / maxf(0.0001, rooted_spore),
			]
		PhaseBProgression.UpgradeId.FRUITING_BODIES:
			return "colonies apply %d%% Spore per cloud, %d%% on rupture" % [
				roundi(combat.fruiting_body_cloud_spore * multiplier * 100.0),
				roundi(combat.fruiting_body_rupture_spore * multiplier * 100.0),
			]
		PhaseBProgression.UpgradeId.BLOOM_FORCE:
			return "%d%% Bloom force, %.0f Bloom damage" % [
				roundi(bloom_director.get_bloom_force_multiplier() * multiplier * 100.0),
				bloom_director.bloom_damage
				* bloom_director.get_bloom_force_multiplier()
				* multiplier,
			]
		PhaseBProgression.UpgradeId.BLOOM_FREQUENCY:
			return "a Bloom every %.1fs" % (
				bloom_director.bloom_interval_seconds
				* bloom_director.get_bloom_interval_multiplier()
				/ multiplier
			)
		PhaseBProgression.UpgradeId.BRAMBLE_ENSNARE_RATE:
			var rate := (
				combat.bramble_entanglement_per_second
				* bramble_director.get_ensnare_multiplier()
				* multiplier
			)
			return "fully Entangled after %.1fs on Green" % (1.0 / maxf(0.01, rate))
		PhaseBProgression.UpgradeId.BRAMBLE_REPULSION:
			return "%.0f px knockback on territory attackers" % (
				bramble_director.get_repulsion_pixels() * multiplier
			)
		PhaseBProgression.UpgradeId.PRUNING_CUTTING_DAMAGE:
			return "%.0f per launched Cutting" % (
				pruning_director.cutting_damage
					* pruning_director.get_pruning_cutting_damage_multiplier()
					* multiplier
			)
		PhaseBProgression.UpgradeId.THISTLE_CLUSTERING, \
		PhaseBProgression.UpgradeId.THISTLE_DEHISCENCE, \
		PhaseBProgression.UpgradeId.THISTLE_BURR, \
		PhaseBProgression.UpgradeId.THISTLE_NEEDLEPOINT:
			return "%.1f damage per ordinary thorn" % (
				adaptation_director.thistle_damage * multiplier
			)
		PhaseBProgression.UpgradeId.VINE_ELONGATION, \
		PhaseBProgression.UpgradeId.VINE_LIGNIFICATION, \
		PhaseBProgression.UpgradeId.VINE_TURGOR, \
		PhaseBProgression.UpgradeId.VINE_APICAL_DOMINANCE:
			var rooted_vine_damage := (
				combat.cane_damage
				* (1.0 + 0.25 * float(
					progression.get_upgrade_level(
						PhaseBProgression.UpgradeId.VINE_LIGNIFICATION
					)
				))
				* multiplier
			)
			return "%.1f Vine damage before Apical/relic modifiers" % rooted_vine_damage
		PhaseBProgression.UpgradeId.FRUIT_SET, \
		PhaseBProgression.UpgradeId.FRUIT_RIPENING, \
		PhaseBProgression.UpgradeId.FRUIT_MOMENTUM, \
		PhaseBProgression.UpgradeId.FRUIT_GERMINATION:
			var rooted_ripening := 1.0 + 0.25 * float(
				progression.get_upgrade_level(PhaseBProgression.UpgradeId.FRUIT_RIPENING)
			)
			return "%.1f collision, up to %.1f terminal damage" % [
				adaptation_director.fruit_collision_damage * rooted_ripening * multiplier,
				adaptation_director.fruit_terminal_explosion_damage * rooted_ripening * multiplier,
			]
		PhaseBProgression.UpgradeId.ROOT_POTENCY:
			return "Seeds, Blooms, thorns, and Cuttings out of Mature ground"
	return ""


func _format_time(seconds: float) -> String:
	var total_seconds := maxi(0, int(ceil(seconds)))
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]


func _get_path_pair_label() -> String:
	if not progression.has_primary_path():
		return "UNCHOSEN PATHS"
	if not progression.has_secondary_path():
		return PhaseBProgression.get_path_name(progression.primary_path).to_upper()
	return "%s + %s" % [
		PhaseBProgression.get_path_name(progression.primary_path).to_upper(),
		PhaseBProgression.get_path_name(progression.secondary_path).to_upper(),
	]


func _set_status(_message: String) -> void:
	# The run no longer carries a field-signal readout. Systems still announce what
	# they did, so the signal stays available for a future surface without every
	# caller having to know whether one exists.
	pass
