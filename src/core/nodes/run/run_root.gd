class_name RunRoot
extends Node2D

const RUN_MODE := preload("res://src/core/models/run/run_mode.gd")

## The screen the pause menu leaves a run for. Loaded by path rather than preloaded:
## the home screen loads this scene in turn, and preloading both ways is a cycle.
const HOME_SCENE := "res://scenes/menu/home_screen.tscn"

## Placeholder reel faces. Each stands for one Path, plus the Clover wild and the Bust.


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

## One queue for every full-screen choice, in the order the design fixes.
##
## A wave can turn over while a draft is already open, an Elite can die inside a
## relic wave, and a milestone's Adaptation offer can arrive alongside two other
## panels. Queuing them means nothing is dropped and nothing opens on top of
## anything else, in the order the design fixes.
enum QueuedReward {
	## The Adaptation offer goes first so the relic that follows can already roll
	## from the pool the new Adaptation just opened. A relic offered a moment
	## earlier would be drawn from a smaller catalogue for no reason the player
	## could see.
	BRANCH_DRAFT,
	MILESTONE_RELIC,
	WAVE_RELIC,
}

@export_group("Gameplay Components")
## Authoritative territory simulation used for ownership, maturity, and run-loss checks.
@export var territory_field: TerritoryField
## Presentation adapter that draws the territory field and authored Seed/Bloom effects.
@export var overlay: TerritoryPrototypeOverlay
## Player component whose health and movement state this run coordinates.
@export var player: Player
## Combat component responsible for enemies, Cane, damage, pickups, and combat audio.
@export var combat: CombatDirector
## Progression component responsible for XP drafts, Biomass, relics, and evolution.
@export var progression: Progression
## Evolutions component owning every Evolution's state and tuning.
@export var evolutions: Evolutions
## Ecosystem Metabolism component. It develops Mass, Push and Hold out of the run's
## lifetime earnings and pushes them into the field as territory strength. Nothing
## here is player-facing any more: there is no meter to watch and nothing to spend.
@export var metabolism: Metabolism
## The Clover machine. Territory is staked here and the reels pay out in Path events.
## Biomass is never touched, so a run can gamble away its body without ever losing the
## growth its lifetime earnings already bought.
@export var slot_machine: SlotMachine
## Draws the region on the table over the arena. Its own layer rather than another
## pass inside the effects overlay: a CanvasItem carries one material, and the wager
## needs a shader of its own to come out smooth instead of as a grid of lit cells.
@export var wager_layer: TerritoryWagerLayer
## Layer drawing the temporary shield a Bloom leaves on the Green it touched. Its own
## node for the same reason the wager highlight is: it belongs to the ground rather
## than to the effects drawn on top of it.
@export var aftergrowth_layer: TerritoryAftergrowthLayer
## Chance, drought protection, and the construction of the visible reel faces.
@export var clover_odds: CloverOdds
## Which cells a given stake would take right now.
@export var wager_selector: WagerSelector
## How long each Path stays lit after the reels pay it out.
@export var clover_jackpots: CloverJackpots
## The three seconds a run gets to rebuild after an All In whiff.
@export var all_in_grace: AllInGrace
## Relic component that owns every triggered relic: its counters, its cooldowns,
## its per-wave state, and the persistent objects relics leave in the arena.
@export var relic_director: RelicDirector
## Wave component responsible for the run timeline, scaling, and enemy reinforcement schedule.
@export var wave_director: WaveDirector
## Plant component responsible for Seeds, Blooms, explosions, and Super Bloom chains.
@export var spore_director: SporeDirector
## Bloom component that owns the Bloom cadence, detonations, and Bloom evolutions.
@export var bloom_director: BloomDirector
## Bramble component that owns that path's tuning and pushes it into the systems.
@export var bramble_director: BrambleDirector
## Root component that owns that path's tuning and its field rules.
@export var root_director: RootDirector
## Man-Eater component: the Legendary relic's Hunger, its Bite, and the meal it
## turns back into Green.
@export var man_eater: ManEater
## Pruning component that owns the cycle, its Cuttings, and Pruned Ground.
@export var pruning_director: PruningDirector
## Runtime for Thistle turrets, Vine pair effects, rolling Fruit, and their relics.
@export var adaptation_director: AdaptationDirector
## Shared SFX and music bus names plus the pause-slider output caps.
@export var audio_settings: AudioSettings

@export_group("Boss Feedback")
## Pixel radius of the visible hostile pulse emitted when the boss erupts.
@export_range(16.0, 300.0, 1.0) var eruption_pulse_radius_pixels := 96.0

@export_group("Run Survival")
## Seconds Green territory may remain at zero before the run ends in defeat.
@export_range(0.0, 30.0, 0.5) var zero_territory_grace_seconds := 6.0

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
## Share of Grandma's maximum health restored by a Compost Cache, which is what a
## relic reward becomes once every eligible relic is already held.
@export_range(0.0, 1.0, 0.01) var compost_cache_heal_fraction := 0.20
## Fresh Green a Compost Cache lays down, as a multiple of a baseline Seed's growth
## mass. Deliberately below one: it repairs a frontier rather than replacing one.
@export_range(0.0, 4.0, 0.05) var compost_cache_growth_mass_scale := 0.75

@export_group("Damage Feedback")
## Full-screen tint that answers being hit without asking the player to look away
## from the fight to read a bar. Optional: without it the run plays exactly as it
## did, minus the flash.
@export var damage_vignette: Control
## Seconds the red flash takes to fade out completely.
@export_range(0.05, 1.5, 0.01) var damage_vignette_seconds := 0.28
## Peak opacity of the flash for a hit costing the whole scaling share below.
## Well under one on purpose: this reports a hit, it does not obscure the arena
## the player has to keep reading through it.
@export_range(0.0, 1.0, 0.01) var damage_vignette_maximum_alpha := 0.42
## Opacity a hit of any size is worth, before the share of maximum health it cost
## is added on top.
@export_range(0.0, 1.0, 0.01) var damage_vignette_minimum_alpha := 0.16
## Share of maximum health a hit must cost to reach the peak opacity, and to earn
## the freeze frame below.
@export_range(0.01, 1.0, 0.01) var heavy_damage_health_fraction := 0.12
## Seconds the whole simulation stops for on a heavy hit.
##
## Tiny by design. Long enough that the hit lands with weight, short enough that it
## reads as impact rather than as the game stuttering -- past about a twentieth of a
## second a freeze stops being juice and starts being a frame drop.
@export_range(0.0, 0.25, 0.005) var heavy_damage_freeze_seconds := 0.04

@export_group("Interface Wiring")
## The run's own sounds: the ambient theme and the three Clover machine voices.
@export var run_audio: RunAudio
## Progress bar that displays the player's current health fraction.
@export var health_bar: ProgressBar
## Label that displays current and maximum player health numerically.
@export var health_label: Label
## Progress bar that displays the percentage of the arena controlled by Green.
@export var territory_bar: ProgressBar
## Draws the rest of the territory bar: what the run does not hold, and how much of
## what it does hold has established. Optional, so a fixture that builds the HUD
## without it still runs.
@export var territory_composition: TerritoryComposition
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
## The run's status line, likewise its own node. Silent at rest: the countdown that
## used to live here made a twenty-five minute Campaign read as a chore, and the
## wave counter already says how far along the run is. It speaks only when there is
## something the wave counter cannot say.
@export var status_label: Label
## The hostile-count warning, its own node so the panel can place it.
@export var hostile_label: Label
## Label that displays selected Plant paths, mastery readiness, and active evolution.
@export var evolution_label: Label
## Label that lists relics acquired during the current run.
@export var relics_label: Label
## Label used for milestone, combat, upgrade, and failure-status messages.
## Row of rounded slots showing which relics the run holds.
@export var relic_slots: UpgradeSlots
## Panel shown while the player chooses an upgrade or relic.
## The Adaptation panel: the Core and Branch rows and the Evolution between them.
@export var adaptation_tree: AdaptationTree
@export var choice_panel: ChoicePanel

@export_group("Clover Machine")
## How near two enemies must be to count as standing together when a Bloom jackpot
## looks for something worth landing on.
@export_range(10.0, 400.0, 5.0) var bloom_jackpot_cluster_radius := 78.0
## Smallest gap between two of that jackpot's anchors, so a big win is spread over
## the fight rather than dropped four times onto one mob.
@export_range(10.0, 600.0, 5.0) var bloom_jackpot_anchor_spacing := 96.0
## The machine's cabinet: reels, lever, wager notch and odds readout, with every
## rule about how they animate. It is the view of `slot_machine`, never its author.
@export var slot_panel: SlotMachinePanel
## Centre-arena countdown shown during the All In grace period.
@export var all_in_label: Label
## Large transient banner over the battlefield for major progression events.
@export var banner_label: Label
## Side-panel button that resets the current run to its initial state.
## Panel shown when the run reaches victory or defeat.
@export var result_panel: Panel
## Heading label used for the victory or defeat result.
@export var result_header: Label
## Label that explains the outcome and summarizes final run statistics.
@export var result_detail: Label

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

@export_group("Collaborators")
## The pause overlay, its settings page, and the volume and fullscreen controls.
## It owns its own presentation and reports what the player asked for; this script
## only decides what pausing costs the run.
@export var pause_menu: PauseMenu
@export var display_settings: DisplaySettings
## Per-spin record of what the Clover machine did. Off unless a playtest turns it
## on, and never read by the machine: an instrument that fed back into the thing it
## measures would stop measuring it.
@export var clover_telemetry: CloverTelemetry
## The interface layer, scaled by the UI Scale setting. The battlefield is a
## sibling of it and is deliberately not scaled: the doc's rule is that scaling
## the interface must not change how much arena the player can see.
@export var interface_layer: CanvasLayer

@export_group("Interface Text")
## Wording for the states a control does not sit in at rest, so every line the
## game can print is edited in the editor rather than in code. The resting wording
## is the text on the node itself; these are the alternates it swaps to. All of
## them take named placeholders - {like_this} - and a placeholder that matches
## nothing is printed as typed, which is how a misspelt name shows itself.
@export var wave_grace_template := "WAVE {wave} IN {seconds}s"
@export var status_complete_text := "CLEAR THE FIELD"
@export var status_detailed_template := "MASS {mass}  PUSH {push}  HOLD {hold}"
@export_multiline var metabolism_complete_template := (
	"LIFETIME BIOMASS {lifetime}
FULLY DEVELOPED"
)
@export var choice_header_upgrade := "ROOT MEMORY"
@export var choice_header_relic := "ELITE RELIC"
## Heading on the milestone offer of lines from Adaptations the run has not
## entered, so the panel says what it is rather than looking like a level-up.
@export var choice_header_branch_draft := "NEW ADAPTATION"
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

## Setting buttons indexed by DisplaySettings.OptionId, so one loop drives
## all seven and an eighth option is one entry rather than a seventh copy.

var _run_state := RunState.RUNNING
var _final_stand_announced := false
## Every dynamic line in the interface, as the scene authored it. Captured once,
## before anything writes to a control, so what is typed in the editor is what the
## game prints - wording, spacing, order, and which values appear at all.
var _authored := AuthoredText.new()
## Every line the interface prints about an upgrade. Built in `_ready`, once the
## components it reads from exist, and handed to anything that draws upgrade text.
var _descriptions: UpgradeDescriptions
var _choice_kind := ChoiceKind.NONE
var _choice_ids := PackedInt32Array()
var _zero_territory_remaining := 0.0
var _owed_wave_relics := 0
## Rewards earned but not yet presented, drained in QueuedReward order whenever the
## screen is clear. Saved as run state so closing one panel can never skip another.
var _reward_queue: Array[int] = []
## Seconds of red screen flash left, and the opacity it started at.
var _damage_vignette_remaining := 0.0
var _damage_vignette_alpha := 0.0
## Seconds the simulation is held still for on a heavy hit. Counted down on real
## time rather than on simulated time, because the whole point is that simulated
## time is what has stopped.
var _hit_freeze_remaining := 0.0
var _banner_remaining := 0.0
## Whether the run is currently choosing where to put a release, and which action is
## waiting on the answer. The run keeps running while it is: the doc treats a release
## as a decision made under pressure, not a pause to plan in.
## Seconds left of the reach ring Circulation throws up when it is developed, so the
## development shows the player what it just widened.
var _conductive_reveal_remaining := 0.0
## The first-pair cinematic. Zero when nothing is focused; while it runs the rest
## of the run is held still and only the machine advances.
## Whether that focus is the once-per-run cinematic, which pauses, or an ordinary
## later tease, which only leans the panel in.
## The slot panel's authored rect, captured before anything scales it, so the focus
## always returns to where the scene put it rather than to wherever it last was.
## How many of the slot's hover regions the pointer is currently inside.
## What each reel is currently showing and what is coming up behind it, plus how far
## the strip has scrolled. Rest positions are read from the scene so an idle reel sits
## exactly where the scene put it.
## Whether the last input came from a controller. The focus ring is a controller
## affordance: with a mouse in hand it is a white box sitting on a button nobody is
## about to press, so it is only shown once a pad is actually being used.
## Authored row lengths, captured before the rows are trimmed to what the run has.
var _maximum_relic_slots := 6
var _hud_accumulator := 0.0
var _base_natural_spread_rate := 0.0
var _base_maturity_resistance_bonus := 0.0
var _base_pressure_advection := 0.0
var _base_small_fragment_decay := 0.0
## Campaign runs without the Clover machine. The run already asks for enough
## attention without a side game to gamble on, so Campaign hides the cabinet and
## advances none of it; Quick still keeps the whole machine.
var _clover_enabled := true
var _mechanics_help: MechanicsHelp


func _ready() -> void:
	var run_mode := RUN_MODE.get_selected()
	_clover_enabled = run_mode != RUN_MODE.Id.CAMPAIGN
	wave_director.configure_mode(run_mode)
	progression.configure_mode(run_mode)
	NinePatchButtonBorder.install_under(self)
	NinePatchPanelBorder.install_under(self)
	assert(territory_field != null, "RunRoot requires TerritoryField")
	assert(overlay != null, "RunRoot requires TerritoryPrototypeOverlay")
	assert(player != null, "RunRoot requires Player")
	assert(combat != null, "RunRoot requires CombatDirector")
	assert(progression != null, "RunRoot requires Progression")
	assert(wave_director != null, "RunRoot requires WaveDirector")
	assert(spore_director != null, "RunRoot requires SporeDirector")
	assert(bloom_director != null, "RunRoot requires BloomDirector")
	assert(bramble_director != null, "RunRoot requires BrambleDirector")
	assert(root_director != null, "RunRoot requires RootDirector")
	assert(man_eater != null, "RunRoot requires ManEater")
	assert(metabolism != null, "RunRoot requires Metabolism")
	assert(slot_machine != null, "RunRoot requires SlotMachine")
	assert(wager_layer != null, "RunRoot requires TerritoryWagerLayer")
	assert(clover_odds != null, "RunRoot requires CloverOdds")
	assert(wager_selector != null, "RunRoot requires WagerSelector")
	assert(clover_jackpots != null, "RunRoot requires CloverJackpots")
	assert(all_in_grace != null, "RunRoot requires AllInGrace")
	assert(relic_director != null, "RunRoot requires RelicDirector")
	assert(pruning_director != null, "RunRoot requires PruningDirector")
	assert(audio_settings != null, "RunRoot requires AudioSettings")
	assert(pause_menu != null, "RunRoot requires PauseMenu")
	_descriptions = UpgradeDescriptions.new(
		progression,
		evolutions,
		combat,
		spore_director,
		bloom_director,
		bramble_director,
		root_director,
		pruning_director,
		adaptation_director,
		territory_field,
		root_potency_note_template,
	)
	# The authored row lengths are the ceiling the run grows toward, so they are
	# read once before either row is trimmed to what the run currently holds.
	if relic_slots != null:
		_maximum_relic_slots = relic_slots.slot_count
	assert(banner_label != null, "RunRoot requires the event banner")
	assert(run_audio != null, "RunRoot requires RunAudio")
	var required_interface_controls: Array[Control] = [
		health_bar,
		health_label,
		territory_bar,
		territory_label,
		xp_bar,
		xp_label,
		wave_label,
		status_label,
		hostile_label,
		evolution_label,
		relics_label,
		relic_slots,
		result_panel,
		result_header,
		result_detail,
	]
	# Before a single frame runs, and so before anything below overwrites a control:
	# from here on the editor owns the wording and this script only fills in numbers.
	_authored.capture(required_interface_controls)
	_authored.capture([
		all_in_label,
		banner_label,
	])
	# Tooltips are authored the same way, on the same nodes.
	_authored.capture(required_interface_controls, "tooltip_text")
	# An axis button draws its wording through a child caption, so its template is
	# the button's own `display_text` rather than the Button `text` nothing shows.
	for interface_control in required_interface_controls:
		assert(
			interface_control != null,
			"RunRoot has an unwired Interface reference at index %d of %d"
			% [required_interface_controls.find(interface_control), required_interface_controls.size()]
		)

	_base_natural_spread_rate = territory_field.tuning.natural_spread_rate
	_base_maturity_resistance_bonus = territory_field.tuning.maturity_resistance_bonus
	_base_pressure_advection = territory_field.tuning.pressure_advection
	_base_small_fragment_decay = territory_field.tuning.small_fragment_decay_per_second

	player.health_changed.connect(_on_health_changed)
	player.damage_taken.connect(_on_player_damage_taken)
	player.died.connect(_on_player_died)
	combat.xp_collected.connect(progression.add_xp)
	combat.elite_defeated.connect(_on_elite_defeated)
	combat.boss_defeated.connect(_on_boss_defeated)
	wave_director.wave_began.connect(_on_wave_began)
	wave_director.wave_relic_earned.connect(_on_wave_relic_earned)
	wave_director.elite_arrived.connect(_on_elite_arrived)
	wave_director.boss_arrived.connect(_on_boss_arrived)
	wave_director.final_invasion_began.connect(_on_final_invasion_began)
	wave_director.cleanup_began.connect(_on_cleanup_began)
	spore_director.status_requested.connect(_set_status)
	bloom_director.status_requested.connect(_set_status)
	combat.boss_erupted.connect(_on_boss_erupted)
	man_eater.status_requested.connect(_set_status)
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
	# The cabinet is the machine's view. It drives the machine directly, because that
	# is what a view of a machine does; what it hands back are the two things a spin
	# costs the run - a status line, and a battlefield that stops for the first pair.
	slot_panel.setup(slot_machine, player, wager_layer, _clover_enabled)
	adaptation_tree.setup(progression, _descriptions)
	adaptation_tree.slot_hovered.connect(_on_tree_slot_hovered)
	if relic_slots != null:
		relic_slots.slot_hovered.connect(_on_hud_slot_hovered.bind(relic_slots))
	slot_panel.spin_started.connect(_on_slot_spin_started)
	slot_panel.spin_refused.connect(_set_status)
	slot_panel.cinematic_started.connect(_on_slot_cinematic_started)
	slot_panel.cinematic_ended.connect(_on_slot_cinematic_ended)
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
	progression.adaptation_mastered.connect(_on_adaptation_mastered)
	progression.core_pair_locked.connect(_on_core_pair_locked)
	progression.compost_cache_granted.connect(_on_compost_cache_granted)
	progression.garden_completed.connect(_on_garden_completed)
	territory_field.metrics_changed.connect(_on_territory_metrics_changed)

	choice_panel.option_chosen.connect(_choose_displayed_option)
	choice_panel.option_hovered.connect(_on_reward_hovered)
	display_settings.settings_changed.connect(_on_display_settings_changed)
	_on_display_settings_changed()
	choice_panel.reroll_requested.connect(_reroll_upgrade_choice)
	progression.rerolls_changed.connect(_on_rerolls_changed)
	# The menu's own children are wired inside it. What it cannot resolve on its own
	# are the two run components living in a different scene, so they are handed over
	# here, and what it reports is connected to the rules that own the answers.
	pause_menu.setup(display_settings, audio_settings)
	pause_menu.opened.connect(_refresh_simulation_pause)
	pause_menu.closed.connect(_refresh_simulation_pause)
	pause_menu.glossary_requested.connect(_open_glossary)
	pause_menu.settings_toggled.connect(_on_pause_settings_toggled)
	pause_menu.main_menu_requested.connect(_return_to_main_menu)
	pause_menu.quit_requested.connect(_quit_from_pause_menu)
	_refresh_dev_controls()
	_build_mechanics_help()

	overlay.show_annotations = false
	_apply_clover_presence()
	reset_run()
	_refresh_dev_controls()

func _process(delta: float) -> void:
	# The focus runs on its own clock outside the run, because the whole point of the
	# cinematic is that the run is not running while it plays.
	slot_panel.advance_focus(delta)
	_advance_damage_feedback(delta)
	if (
		_run_state == RunState.RUNNING
		and _choice_kind == ChoiceKind.NONE
		and not pause_menu.is_open()
		and not is_pair_cinematic_active()
		and _hit_freeze_remaining <= 0.0
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
	pause_menu.note_input_device(event)
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
		if pause_menu.is_open() and pause_menu.is_settings_open():
			# Escape backs out of the settings page first, so the key never closes the
			# whole menu out from under a player who only opened a page with it.
			pause_menu.show_settings(false)
		elif pause_menu.is_open():
			_close_pause_menu()
		elif _choice_kind == ChoiceKind.NONE:
			_open_pause_menu()
		get_viewport().set_input_as_handled()
		return
	if pause_menu.is_open():
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
	if not _clover_enabled:
		_set_status("Campaign runs without the Clover machine.")
		return
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
	if not _clover_enabled:
		_set_status("Campaign runs without the Clover machine.")
		return
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
		territory_field.get_mature_percent_of_arena(),
		1.0
	)
	if _clover_enabled:
		slot_machine.advance(delta)
		slot_machine.advance_preview(delta, player.get_arena_position())
		clover_jackpots.advance(delta)
		all_in_grace.advance(delta)
		_advance_all_in_countdown()
		slot_panel.advance_spin(delta)

	wave_director.advance(delta)
	# Adaptation choosers share the panel with relic rewards and land on the same
	# wave boundaries, so both go through one queue in the design's fixed order
	# rather than racing each other for the screen.
	_grant_owed_wave_relic()
	_drain_reward_queue()
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
	slot_panel.reset_panel()
	overlay.clear_overgrow_aim()
	_run_state = RunState.RUNNING
	_final_stand_announced = false
	_choice_kind = ChoiceKind.NONE
	_choice_ids.clear()
	_zero_territory_remaining = zero_territory_grace_seconds
	_owed_wave_relics = 0
	_reward_queue.clear()
	_damage_vignette_remaining = 0.0
	_damage_vignette_alpha = 0.0
	_hit_freeze_remaining = 0.0
	_update_damage_vignette()
	_hud_accumulator = 999.0
	choice_panel.hide_options()
	result_panel.visible = false
	pause_menu.close()
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
	relic_director.reset_director()
	player.reset_player()
	combat.reset_combat()
	# One seed for the whole run. The Campaign's leader decks and its opening
	# perimeter sector come out of the same number the drafting does, so replaying a
	# seed replays the waves as well as the upgrades.
	wave_director.set_run_seed(progression.run_seed)
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
	_grant_owed_wave_relic()
	_drain_reward_queue()
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


func get_final_wave_number() -> int:
	return wave_director.get_final_wave_number()


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
	if wave_director.is_campaign_mode():
		# Campaign authors its ten relic opportunities on the wave table and
		# announces each one through the director; Quick keeps its repeating cycle.
		var spec := wave_director.get_wave_spec(wave_number)
		if spec != null:
			_set_status("WAVE %d — %s" % [wave_number, String(spec.display_name)])
	elif relic_reward_wave_cycle > 0 and wave_number % relic_reward_wave_cycle == 0:
		_owed_wave_relics += 1
	_grant_owed_wave_relic()
	_drain_reward_queue()


func _on_wave_relic_earned(_wave_number: int) -> void:
	_queue_reward(QueuedReward.WAVE_RELIC)
	_drain_reward_queue()


func _queue_reward(reward: int) -> void:
	_reward_queue.append(reward)
	# Sorted rather than appended blind: the queue's order is the design's, so a
	# milestone relic that arrives after a Branch reward is still presented first.
	_reward_queue.sort()


func _drain_reward_queue() -> void:
	## Opens the next owed panel, if the screen is clear and the run is live. One
	## panel at a time, and the queue survives whatever closes the current one.
	if _run_state != RunState.RUNNING:
		return
	if _choice_kind != ChoiceKind.NONE or progression.has_pending_upgrade_choice():
		return
	if progression.has_pending_relic_choice():
		return
	while not _reward_queue.is_empty():
		var reward: int = _reward_queue[0]
		_reward_queue.remove_at(0)
		match reward:
			QueuedReward.BRANCH_DRAFT:
				if progression.request_branch_upgrade_choice():
					return
			QueuedReward.MILESTONE_RELIC, QueuedReward.WAVE_RELIC:
				if progression.request_relic_choice():
					return


func _grant_owed_wave_relic() -> void:
	# A wave can turn over while a draft is already on the table, so the reward
	# waits for the panel to clear instead of being dropped.
	if _owed_wave_relics <= 0 or _run_state != RunState.RUNNING:
		return
	if _choice_kind != ChoiceKind.NONE or progression.has_pending_relic_choice():
		return
	_owed_wave_relics -= 1
	if progression.request_relic_choice():
		_set_status(
			"WAVE %d — the frontier yields a relic." % wave_director.get_current_wave_number()
		)



func _on_adaptation_mastered(path_id: int) -> void:
	_set_status("%s MASTERED — all its upgrades have reached rank 3." % (
		Progression.get_path_name(path_id).to_upper()
	))


func _on_core_pair_locked(core_a: int, core_b: int, evolution_id: int) -> void:
	_set_status("%s + %s — this run's Evolution is %s." % [
		Progression.get_path_name(core_a),
		Progression.get_path_name(core_b),
		Evolutions.get_evolution_name(evolution_id),
	])


func _on_garden_completed() -> void:
	_set_status("GARDEN COMPLETE — every rank this run can hold has been grown.")


func _on_compost_cache_granted() -> void:
	## What an exhausted relic pool pays out instead of a currency the run has no
	## remaining use for: health, and a patch of Fresh Green put back on the
	## frontier. A reward event rather than a Seed germination, so nothing that
	## counts Seeds counts this.
	player.heal(player.maximum_health * compost_cache_heal_fraction)
	territory_field.queue_seed_growth(
		_find_compost_cache_site(),
		compost_cache_growth_mass_scale
	)
	_set_status("COMPOST CACHE — no relic remains, so the frontier is fed instead.")


func _find_compost_cache_site() -> Vector2:
	# The nearest valid owned frontier point, or Grandma herself when the run holds
	# no frontier the cache could be laid on.
	var origin := player.get_arena_position()
	var nearest := origin
	var nearest_distance := INF
	for index in range(territory_field.get_cell_count()):
		if not territory_field.is_owned_cell(index):
			continue
		var position := territory_field.get_cell_local_position(index)
		var distance := position.distance_squared_to(origin)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = position
	return nearest


func _on_elite_arrived() -> void:
	_set_status("ELITE ROOTBREAKER — defeat it to choose a relic.")


func _on_boss_arrived() -> void:
	_set_status("THE BURROWER SURFACES — its eruptions erase Green.")


func _on_final_invasion_began() -> void:
	# Campaign's final invasion is Wave 25 itself rather than a phase bolted after
	# the waves, so it announces a minute rather than two.
	_set_status(
		"FINAL INVASION — hold the frontier for one more minute."
		if wave_director.is_campaign_mode()
		else "FINAL INVASION — hold the frontier for two more minutes."
	)


func _on_cleanup_began() -> void:
	_set_status("LAST ROOTS — no more reinforcements. Survive the remaining hostiles.")


func _on_elite_defeated() -> void:
	# The Elite is the run's first build check, and its reward is both a relic and
	# the first Branch: breadth arrives once the Core pair has been tested.
	_queue_reward(QueuedReward.MILESTONE_RELIC)
	# The Elite is the run's first build check, and beating it earns room for a
	# third Adaptation. The room, not the Adaptation: what grows in it is still
	# drafted, the same way the Core pair was.
	if progression.unlock_branch_slot():
		_queue_reward(QueuedReward.BRANCH_DRAFT)
		_set_status("ROOTBREAKER FELLED — a relic, and room for a new Adaptation.")
	_drain_reward_queue()


func _on_boss_defeated() -> void:
	_queue_reward(QueuedReward.MILESTONE_RELIC)
	if progression.unlock_branch_slot():
		_queue_reward(QueuedReward.BRANCH_DRAFT)
		_set_status("THE BURROWER FALLS — a relic, and room for your last Adaptation.")
	else:
		_set_status("BOSS DEFEATED — claim a relic from its remains.")
	_drain_reward_queue()

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
	# Upgrade and relic drafts both sample a pool, so both can be redrawn. Path
	# and Breakthrough offers present every option there is, so they cannot.
	if _choice_kind == ChoiceKind.RELIC:
		choice_panel.set_reroll_state(true, progression.get_relic_rerolls_remaining())
		return
	choice_panel.set_reroll_state(
		_choice_kind == ChoiceKind.UPGRADE,
		progression.rerolls_remaining,
	)


func _on_relic_choice_requested(options: PackedInt32Array) -> void:
	_show_choice(ChoiceKind.RELIC, options)


func _show_choice(kind: int, options: PackedInt32Array) -> void:
	_choice_kind = kind
	_choice_ids = options.duplicate()
	if _mechanics_help != null:
		_mechanics_help.hide_tooltip()
	_update_reroll_button()
	var header_text := ""
	match kind:
		ChoiceKind.UPGRADE:
			# The milestone offer is a draft like any other; only its heading says
			# that the lines on it belong to Adaptations the run has not entered.
			header_text = (
				choice_header_branch_draft
				if progression.is_pending_branch_upgrade_choice()
				else choice_header_upgrade
			)
		ChoiceKind.RELIC:
			header_text = choice_header_relic
	# The panel draws cards; what a card says is built here, because it is read off
	# progression and the Root Network and neither of those is a panel's business.
	var entries: Array = []
	for option_id in _choice_ids:
		entries.append(_build_choice_entry(kind, option_id))
	choice_panel.show_options(header_text, entries)
	_refresh_simulation_pause()


func _build_choice_entry(kind: int, option_id: int) -> Dictionary:
	if kind == ChoiceKind.UPGRADE and option_id == Progression.EVOLUTION_DRAFT_OPTION:
		var pair_evolution := progression.get_pair_evolution_id()
		return {"text": AuthoredText.render(choice_evolution_template, {
			"name": Evolutions.get_evolution_name(pair_evolution),
			"detail": Evolutions.get_evolution_description(pair_evolution),
		})}
	if kind == ChoiceKind.UPGRADE:
		var current_upgrade_level := progression.get_upgrade_level(option_id)
		# What the rank buys, and under it what the Root Network makes of the
		# line once it is taken. The draft is where the choice is made, so the
		# amplified number belongs on the card and not only in the hover.
		var detail := progression.get_upgrade_description(option_id)
		var rooted := _descriptions.root_potency_note(option_id)
		if not rooted.is_empty():
			detail += "
%s" % rooted
		return {"text": AuthoredText.render(choice_upgrade_template, {
			"name": Progression.get_upgrade_name(option_id),
			"level": current_upgrade_level,
			"next": current_upgrade_level + 1,
			"detail": detail,
		})}
	# Rarity is the readout of how much the relic changes, so it is named on the
	# card rather than only implied by the effect text.
	var rarity := RelicCatalog.get_rarity(option_id)
	return {
		"text": AuthoredText.render(choice_relic_template, {
			"name": Progression.get_relic_name(option_id),
			"rarity": RelicCatalog.get_rarity_name(rarity),
			"detail": progression.get_relic_description(option_id),
		}),
		"modulate": RelicCatalog.get_rarity_color(rarity),
	}


func _choose_displayed_option(index: int) -> void:
	if index < 0 or index >= _choice_ids.size():
		return
	var selected_id := _choice_ids[index]
	var prior_kind := _choice_kind
	_choice_kind = ChoiceKind.NONE
	_choice_ids.clear()
	choice_panel.hide_options()
	_mechanics_help.hide_tooltip()
	_update_reroll_button()
	if prior_kind == ChoiceKind.UPGRADE and selected_id == Progression.EVOLUTION_DRAFT_OPTION:
		var evolved_pair := _get_path_pair_label()
		if progression.choose_pair_evolution():
			_set_status("%s has evolved into %s." % [
				evolved_pair,
				Evolutions.get_evolution_name(progression.active_evolution),
			])
	elif prior_kind == ChoiceKind.UPGRADE:
		# Taking a line of an Adaptation the run has not entered is what enters it,
		# so the status says which slot the choice just filled.
		var committed_path := progression.get_upgrade_committed_path(selected_id)
		var slot_kind := progression.get_next_slot_kind()
		if progression.choose_upgrade(selected_id):
			if committed_path == Progression.UNSELECTED_PATH:
				_set_status(
					"Upgrade rooted: %s." % Progression.get_upgrade_name(selected_id)
				)
			else:
				_set_status("Upgrade rooted: %s. Your %s Adaptation is now %s." % [
					Progression.get_upgrade_name(selected_id),
					(
						"Core"
						if slot_kind == Progression.SlotKind.CORE
						else "Branch"
					),
					Progression.get_path_name(committed_path),
				])
	elif prior_kind == ChoiceKind.RELIC:
		if progression.choose_relic(selected_id):
			_set_status("Relic claimed: %s." % Progression.get_relic_name(selected_id))
	_grant_owed_wave_relic()
	_drain_reward_queue()
	_refresh_simulation_pause()


func _on_display_settings_changed() -> void:
	# One place applies everything, because several of these change the same frame and
	# each having its own listener would apply them in whatever order the connections
	# happened to be made in.
	if interface_layer != null:
		interface_layer.transform = Transform2D.IDENTITY
	pause_menu.refresh_setting_buttons()
	if is_node_ready():
		_update_hud()
	if player != null:
		player.queue_redraw()
	if overlay != null:
		overlay.queue_redraw()


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


func _on_wager_preview_changed(cells: PackedInt32Array) -> void:
	if cells.is_empty() and not slot_machine.is_revealing():
		wager_layer.clear_wager()
		return
	if slot_machine.is_preview_visible():
		wager_layer.set_wager_cells(cells, false)


func _on_reels_started(stake: int, committed_cells: PackedInt32Array) -> void:
	# The faces are already decided; what follows is the reveal. The blur is filled with
	# arbitrary symbols so the reels do not appear to scroll through the answer.
	slot_panel.scramble_incoming_faces()
	_set_status("%s stake — %d cells of Green on the table." % [
		CloverSlot.get_stake_name(stake).to_upper(),
		committed_cells.size(),
	])
	slot_panel.refresh_controls()


func _on_hud_slot_hovered(index: int, row: UpgradeSlots) -> void:
	# The relic row, which lives in the tray rather than the Adaptation panel and so
	# is still this script's to describe.
	var description := row.get_slot_tooltip(index)
	if description.is_empty():
		return
	var title := description.get_slice("
", 0).strip_edges()
	_mechanics_help.show_hud_tooltip(
		title, MechanicsHelp.tooltip_body(description, title), row.get_slot_global_rect(index)
	)


func _on_tree_slot_hovered(title: String, body: String, anchor: Rect2) -> void:
	_mechanics_help.show_hud_tooltip(title, body, anchor)


func _on_slot_spin_started() -> void:
	run_audio.play_lever()


func _on_reel_stopped(_reel_index: int, _symbol: int) -> void:
	run_audio.play_reel()
	slot_panel.refresh_reels()


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
	slot_panel.begin_pair_focus(first_of_run)


func _on_slot_cinematic_started() -> void:
	# The battlefield stops and the machine does not. Everything else in the run is
	# advanced from advance_run, which the focus gates; the panel advances the reels
	# itself, so they keep turning inside the pause.
	_set_simulation_paused(true)


func _on_slot_cinematic_ended() -> void:
	if _run_state == RunState.RUNNING:
		_set_simulation_paused(false)


func is_pair_focus_active() -> bool:
	return slot_panel.is_pair_focus_active()


func is_pair_cinematic_active() -> bool:
	return slot_panel.is_pair_cinematic_active()


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
		run_audio.play_jackpot()
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
	slot_panel.refresh_controls()


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
		Progression.PathId.SPORE:
			_fire_spore_jackpot(jackpot_scale)
		Progression.PathId.BLOOM:
			_fire_bloom_jackpot(jackpot_scale)
		Progression.PathId.PRUNING:
			# The casino supplies the clippings outright. Running a harvest cycle would
			# make the jackpot pay for itself out of the player's own Green, and doing
			# nothing would hand them a maxed Pruning with an empty ring and a wait.
			pruning_director.grant_free_cuttings(
				clampi(roundi(4.0 * jackpot_scale), 2, 12)
			)
		Progression.PathId.THISTLE, Progression.PathId.VINE, Progression.PathId.FRUIT:
			adaptation_director.fire_slot_jackpot(path_id, jackpot_scale)


func _on_jackpot_window_changed(path_id: int, total_seconds: float) -> void:
	_apply_progression_modifiers()
	_set_status("%s JACKPOT — %.0f seconds." % [
		Progression.get_path_name(path_id).to_upper(),
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
			return Progression.PathId.ROOT
		CloverSlot.Symbol.SPORE:
			return Progression.PathId.SPORE
		CloverSlot.Symbol.BLOOM:
			return Progression.PathId.BLOOM
		CloverSlot.Symbol.BRAMBLE:
			return Progression.PathId.BRAMBLE
		CloverSlot.Symbol.PRUNING:
			return Progression.PathId.PRUNING
		CloverSlot.Symbol.THISTLE:
			return Progression.PathId.THISTLE
		CloverSlot.Symbol.VINE:
			return Progression.PathId.VINE
		CloverSlot.Symbol.FRUIT:
			return Progression.PathId.FRUIT
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
	if not _clover_enabled:
		return
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
		progression.has_path_active(Progression.PathId.SPORE),
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
		progression.has_active_evolution(Progression.EvolutionId.OLD_GROWTH)
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


func _on_player_damage_taken(amount: float) -> void:
	# Where the run is actually being hurt, which is part of where the next pack
	# should come from. A crowded sector is not the same as a dangerous one.
	wave_director.report_sector_pressure(player.get_arena_position(), amount)
	# Three answers to one hit, each aimed at a different failure to notice it: the
	# number says how much, the screen says at all, and the freeze says it mattered.
	combat.spawn_player_damage_number(player.get_arena_position(), amount)
	var severity := clampf(
		amount / maxf(1.0, player.maximum_health * heavy_damage_health_fraction),
		0.0,
		1.0
	)
	_damage_vignette_alpha = lerpf(
		damage_vignette_minimum_alpha,
		damage_vignette_maximum_alpha,
		severity
	)
	_damage_vignette_remaining = damage_vignette_seconds
	if severity >= 1.0:
		# Only a heavy hit freezes. A micro-freeze on every chip of contact damage
		# would read as the game running badly rather than as anything landing.
		_hit_freeze_remaining = heavy_damage_freeze_seconds
		_refresh_simulation_pause()
	_update_damage_vignette()


func _advance_damage_feedback(delta: float) -> void:
	## Runs on real time, outside the run's own clock, so the flash still fades and
	## the freeze still ends while the simulation is held still.
	if _hit_freeze_remaining > 0.0:
		_hit_freeze_remaining = maxf(0.0, _hit_freeze_remaining - delta)
		if _hit_freeze_remaining <= 0.0:
			_refresh_simulation_pause()
	if _damage_vignette_remaining <= 0.0:
		return
	_damage_vignette_remaining = maxf(0.0, _damage_vignette_remaining - delta)
	_update_damage_vignette()


func _update_damage_vignette() -> void:
	if damage_vignette == null:
		return
	var fade := (
		_damage_vignette_remaining / maxf(0.001, damage_vignette_seconds)
	)
	# Squared rather than linear: a hit should read as a sharp strike that decays,
	# not as a red pane sliding evenly off the screen.
	var alpha := _damage_vignette_alpha * fade * fade
	damage_vignette.visible = alpha > 0.001
	damage_vignette.modulate.a = alpha


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
	hostile_percent: float,
	neutral_percent: float,
	mature_player_percent: float,
	_fragment_count: int
) -> void:
	if not is_node_ready():
		return
	territory_bar.value = player_percent
	if territory_composition != null:
		# Neutral and Rot are different situations rather than two ways of not being
		# Green: available soil recovers, entrenched ground has to be taken. The bar
		# used to render both as the same empty space, so it could not say which of
		# the two the run was actually in.
		territory_composition.set_composition(
			player_percent,
			neutral_percent,
			hostile_percent,
			mature_player_percent
		)
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
	# Guarded because an exported setter runs while the scene is still being built,
	# long before the menu that shows the card has been resolved.
	if not is_node_ready() or pause_menu == null:
		return
	pause_menu.set_dev_controls_enabled(dev_controls_enabled)


func is_pause_menu_open() -> bool:
	return pause_menu.is_open()


func _build_mechanics_help() -> void:
	_mechanics_help = MechanicsHelp.new()
	interface_layer.add_child(_mechanics_help)
	_mechanics_help.glossary_closed.connect(_on_glossary_closed)
	if all_in_label != null:
		all_in_label.visible = false
	wager_layer.clear_wager()


func _on_reward_hovered(_index: int, button: Button) -> void:
	if _choice_kind == ChoiceKind.NONE:
		return
	var panel_rect := choice_panel.get_global_rect()
	var anchor := Rect2(panel_rect.end.x, button.get_global_rect().position.y, 0.0, 0.0)
	_mechanics_help.show_reward_tooltips(button.text, anchor)


func _apply_clover_presence() -> void:
	# Quick keeps the machine exactly as the scene authored it.
	if _clover_enabled:
		# All but the Adaptation heading, which the cabinet sits on top of. The four
		# rows under it are self-describing -- each names its own Adaptation -- so the
		# word is what gives way rather than the panel being re-laid out around it.
		adaptation_tree.set_heading_visible(false)
		return
	adaptation_tree.set_heading_visible(true)
	# The cabinet goes, and the Adaptation rows move up into the space it held rather
	# than leaving a hole in the middle of the panel. Where they move to is read off
	# the cabinet itself, so the two stay in step whenever the scene moves either one.
	if slot_panel != null:
		slot_panel.visible = false
		adaptation_tree.position.y = slot_panel.position.y
	if all_in_label != null:
		all_in_label.visible = false
	wager_layer.clear_wager()


func _on_pause_settings_toggled(_settings_open: bool) -> void:
	# The glossary is drawn over the pause panel, so a page change beneath it would
	# otherwise leave it stranded on top of whichever page won.
	if _mechanics_help != null and _mechanics_help.is_glossary_open():
		_mechanics_help.close_glossary()


func _open_glossary() -> void:
	pause_menu.hide_panels()
	_mechanics_help.open_glossary()


func _close_glossary() -> void:
	_mechanics_help.close_glossary()


func _on_glossary_closed() -> void:
	if pause_menu.is_open():
		pause_menu.show_panel()


func _open_pause_menu() -> void:
	# A draft already owns the screen and already pauses the simulation, so pausing
	# on top of one would be two overlays deep for no extra state.
	if _choice_kind != ChoiceKind.NONE:
		return
	pause_menu.open()


func is_controller_active() -> bool:
	return pause_menu.is_controller_active()


func _close_pause_menu() -> void:
	pause_menu.close()


func _return_to_main_menu() -> void:
	# The run is abandoned rather than saved: the home screen starts a fresh one.
	_close_pause_menu()
	get_tree().change_scene_to_file.call_deferred(HOME_SCENE)


func _quit_from_pause_menu() -> void:
	get_tree().quit()


func _refresh_simulation_pause() -> void:
	_set_simulation_paused(
		pause_menu.is_open()
		or _choice_kind != ChoiceKind.NONE
		or _run_state != RunState.RUNNING
		# The hit freeze stops everything, including the components that step
		# themselves. A freeze that only paused half the simulation would be enemies
		# sliding through a stationary player rather than a moment of impact.
		or _hit_freeze_remaining > 0.0
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
	slot_panel.refresh_controls()
	if not is_node_ready():
		return
	var wave_values := {
		"wave": get_current_wave_number(),
		"waves": get_final_wave_number(),
		"seconds": "%02d" % ceili(get_wave_grace_remaining_seconds()),
	}
	var status_values := {
		"mass": metabolism.get_level(Metabolism.SystemId.PHOTOSYNTHESIS),
		"push": metabolism.get_level(Metabolism.SystemId.MERISTEM),
		"hold": metabolism.get_level(Metabolism.SystemId.CAMBIUM),
	}
	# Silent at rest, which is what the node itself says. The run's progress is the
	# wave counter's job; this line is for the states the counter has no room for.
	var status_template := _authored.template(status_label)
	if wave_director.is_complete():
		# The last wave has been spawned: what remains between the player and victory
		# is the hostiles still standing.
		status_template = status_complete_text
	elif display_settings.is_hud_detailed():
		# Detailed reveals more of the same line rather than adding a second one: the
		# doc rules out a separate design, so what changes is how much this says.
		status_template = status_detailed_template
	# Absence communicates zero: the hostile count is a warning, so it appears only
	# while there is something to warn about.
	var hostiles := combat.get_active_enemy_count()
	# One node each, placed by the scene. They shared a label until the gap between
	# them was a run of spaces inside a format string, which meant neither could be
	# moved, coloured, or sized without editing code and counting spaces.
	if is_wave_grace_period_active():
		_authored.write_variant(wave_label, wave_grace_template, wave_values)
	else:
		# The number and nothing else. Campaign waves still carry a display name in
		# the wave tables; it is simply not written onto this line.
		_authored.write(wave_label, wave_values)
	_authored.write_variant(status_label, status_template, status_values)
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
		Progression.EvolutionStatus.READY:
			# What a pairing becomes is the discovery, so it is not printed here
			# before the player has ever seen it. The colour shift is the whole of
			# the signal, the same way it is once the run has evolved.
			evolution_label.text = ""
			evolution_label.modulate = Color("b2cb82")
		Progression.EvolutionStatus.EVOLVED:
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
	adaptation_tree.refresh()



func _update_relic_slots() -> void:
	if relic_slots == null:
		return
	# The pool is far larger than the row, so the row shows what the run actually
	# holds, in the order it was taken, with the trigger counter a relic needs to
	# be readable on the slot itself.
	var held := PackedInt32Array()
	for relic_id in range(RelicCatalog.get_count()):
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
				UpgradeSlots.SlotState.EMPTY
			)
			continue
		var relic_id := held[index]
		var relic_name := Progression.get_relic_name(relic_id)
		var rarity := RelicCatalog.get_rarity(relic_id)
		var tooltip := "%s   %s\n%s" % [
			relic_name,
			RelicCatalog.get_rarity_name(rarity),
			progression.get_relic_description(relic_id),
		]
		var counter := relic_director.get_relic_counter_text(relic_id)
		if not counter.is_empty():
			tooltip += "\nProgress: %s" % counter
		relic_slots.set_slot(
			index,
			UpgradeDescriptions.initials(relic_name),
			counter,
			tooltip,
			UpgradeSlots.SlotState.FILLED,
			# Rarity on the slot itself, so the row reads as a collection at a glance
			# rather than only under the pointer. Colour is never the only signal: the
			# tooltip still names the rarity in words, which is the same rule the reel
			# faces and the Bust symbol follow.
			RelicCatalog.get_rarity_color(rarity)
		)


func _format_time(seconds: float) -> String:
	var total_seconds := maxi(0, int(ceil(seconds)))
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]


func _get_path_pair_label() -> String:
	if not progression.has_primary_path():
		return "UNCHOSEN PATHS"
	if not progression.has_secondary_path():
		return Progression.get_path_name(progression.primary_path).to_upper()
	return "%s + %s" % [
		Progression.get_path_name(progression.primary_path).to_upper(),
		Progression.get_path_name(progression.secondary_path).to_upper(),
	]


func _set_status(_message: String) -> void:
	# The run no longer carries a field-signal readout. Systems still announce what
	# they did, so the signal stays available for a future surface without every
	# caller having to know whether one exists.
	pass
