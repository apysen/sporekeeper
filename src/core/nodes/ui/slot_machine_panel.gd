class_name SlotMachinePanel
extends Control

## The Clover machine's cabinet: three reels, the lever, the wager notch, and the
## odds readout.
##
## This is the machine's *view and input surface*, not the machine. `SlotMachine`
## decides every outcome before a reel finishes moving; everything here reads that
## decision and animates it, which is what keeps the near-miss rewind an animation
## rather than a rig. Nothing in this file may change a result.
##
## What it deliberately does not own is what a spin costs the run: the jackpots it
## fires, the banner it raises, and the battlefield the first pair of a run freezes
## are all run rules, so the panel reports `spin_started`, `cinematic_started` and
## `cinematic_ended` and lets the run root answer them.

## The lever was pulled and the machine accepted it.
signal spin_started
## The player pulled the lever and the machine refused. Carries the wording, because
## the side-panel status line belongs to the run root.
signal spin_refused(message: String)
## A first-pair cinematic began. The run root stops the battlefield; the panel keeps
## the reels turning inside that pause, since they are what the player is watching.
signal cinematic_started
## That cinematic finished.
signal cinematic_ended

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

@export_group("Reels")
## The three reel windows, left to right. Each clips a two-face strip that scrolls
## through it, so a spin looks like reels turning rather than three icons changing.
@export var reel_one: Control
@export var reel_two: Control
@export var reel_three: Control
## Faces a reel scrolls past per second while it is turning.
@export_range(1.0, 40.0, 0.5) var reel_scroll_speed := 11.0

@export_group("Wager")
## Notched wager control. Three positions, because a continuous dial invites fiddling
## and a notch is a decision the player can name.
@export var wager_slider: HSlider
@export var wager_label: Label
## The odds readout under the machine: what a spin currently pays and what it currently
## risks, after drought protection and Bust suppression. The machine is allowed to
## protect the player from ugly randomness; it is not allowed to print a number it is
## not about to roll.
@export var odds_label: Label

@export_group("Lever")
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

@export_group("Pair Focus")
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

@export_group("Text")
## Wording the panel swaps to once the buy-in is met. The resting wording on the
## node itself is what it says before that.
@export var wager_stake_template := "{stake}   {percent}% TERRITORY"
@export var odds_live_template := "JACKPOT {jackpot}%    BUST {bust}%"

var _authored := AuthoredText.new()
var _machine: SlotMachine
var _player: Player
var _wager_layer: TerritoryWagerLayer
var _enabled := false

var _reel_symbol := PackedInt32Array([5, 5, 5])
var _reel_incoming := PackedInt32Array([5, 5, 5])
var _reel_offset := PackedFloat32Array([0.0, 0.0, 0.0])
var _reel_rest_a := PackedFloat32Array([0.0, 0.0, 0.0])
var _reel_rest_b := PackedFloat32Array([0.0, 0.0, 0.0])

var _lever_seated := false
var _lever_seat_remaining := 0.0

var _pair_focus_remaining := 0.0
var _pair_focus_total := 0.0
var _pair_focus_is_cinematic := false
var _panel_home := Rect2()
var _panel_home_captured := false
var _hover_regions := 0


func _ready() -> void:
	_authored.capture([wager_label, odds_label])
	lever_grab.gui_input.connect(_on_lever_input)
	wager_slider.value_changed.connect(_on_wager_changed)
	# The machine, the stake meter and the lever all count as looking at the slot. Only
	# the panel would do if its children ignored the mouse, but the slider and the lever
	# grab take input, and hovering either of those would otherwise read as leaving.
	for hover_region: Control in [self, wager_slider, lever_grab]:
		if hover_region == null:
			continue
		hover_region.mouse_entered.connect(_on_hover_changed.bind(true))
		hover_region.mouse_exited.connect(_on_hover_changed.bind(false))


## Hands over the machine this panel is a view of, plus the two run components a
## spin reads and writes. The run root calls this from its own `_ready`.
func setup(
	machine: SlotMachine,
	arena_player: Player,
	wager_layer: TerritoryWagerLayer,
	enabled: bool
) -> void:
	_machine = machine
	_player = arena_player
	_wager_layer = wager_layer
	_enabled = enabled
	_capture_reel_rest_positions()
	_reel_symbol = _machine.get_last_symbols().duplicate()
	_reel_incoming = _machine.get_last_symbols().duplicate()
	refresh_reels()
	refresh_controls()
	_refresh_lever()


## Called every frame, whether or not the run itself is advancing: the focus is what
## holds the battlefield still, and it keeps the reels turning inside its own pause.
func advance_focus(delta: float) -> void:
	_advance_pair_focus(delta)


## Called only while the run is advancing and the machine is in play, so a lever
## does not spring back and reels do not turn behind a pause menu.
func advance_spin(delta: float) -> void:
	_advance_lever(delta)
	advance_reels(delta)


func reset_panel() -> void:
	_pair_focus_remaining = 0.0
	_pair_focus_is_cinematic = false
	_lever_seated = false
	_reel_offset = PackedFloat32Array([0.0, 0.0, 0.0])
	_reel_symbol = _machine.get_last_symbols().duplicate()
	_reel_incoming = _machine.get_last_symbols().duplicate()
	_apply_focus(1.0)
	_refresh_lever()
	refresh_reels()


func is_pair_focus_active() -> bool:
	return _pair_focus_remaining > 0.0


func is_pair_cinematic_active() -> bool:
	return _pair_focus_remaining > 0.0 and _pair_focus_is_cinematic


## The first two reels agreed. `cinematic` is true only for the first pair of a run.
func begin_pair_focus(cinematic: bool) -> void:
	# The focus lasts exactly as long as the third reel has left to run, plus the way
	# in and the way out. Read from the machine rather than authored a second time:
	# a rewind extends the third reel by most of a second, and a cinematic that ended
	# before the reel it is focused on would be the worst possible version of this.
	var reel_remaining := maxf(
		0.0,
		_machine.get_reveal_duration() - _machine.get_elapsed_seconds()
	)
	_pair_focus_is_cinematic = cinematic
	_pair_focus_total = (
		pair_focus_in_seconds + reel_remaining + pair_focus_out_seconds
	)
	_pair_focus_remaining = _pair_focus_total
	if cinematic:
		# The battlefield stops and the machine does not. Everything else in the run
		# is gated on this focus; the machine is advanced by the focus itself, so the
		# reels keep turning inside the pause.
		cinematic_started.emit()


## Fills the blur with arbitrary faces at the start of a reveal, so the reels do not
## appear to scroll through the answer they have already been given.
func scramble_incoming_faces() -> void:
	for reel_index in range(3):
		_reel_incoming[reel_index] = randi() % CloverSlot.Symbol.size()


func refresh_reels() -> void:
	for reel_index in range(3):
		var reel := reel_window(reel_index)
		if reel == null:
			continue
		var face_a := reel.get_node_or_null("FaceA") as TextureRect
		var face_b := reel.get_node_or_null("FaceB") as TextureRect
		var offset := _reel_offset[reel_index]
		if face_a != null:
			face_a.texture = symbol_texture(_reel_symbol[reel_index])
			face_a.position.y = _reel_rest_a[reel_index] + offset
			_tint_face(face_a, _reel_symbol[reel_index])
		if face_b != null:
			face_b.texture = symbol_texture(_reel_incoming[reel_index])
			face_b.position.y = _reel_rest_b[reel_index] + offset
			_tint_face(face_b, _reel_incoming[reel_index])


func refresh_controls() -> void:
	if not _enabled or not is_node_ready() or _machine == null:
		return
	var stake_name := CloverSlot.get_stake_name(_machine.get_stake()).to_upper()
	if not _machine.is_buy_in_met():
		# The machine stays visible and says exactly what is missing. Hiding it would
		# make the requirement invisible, and a large tutorial panel would make a
		# two-number condition look like a system.
		_authored.write(wager_label)
		_authored.write(odds_label, {
			"held": "%.1f" % (_machine.get_established_fraction() * 100.0),
			"need": "%.1f" % (
				_machine.minimum_buyin_established_fraction * 100.0
			),
		})
	else:
		_authored.write_variant(wager_label, wager_stake_template, {
			"stake": stake_name,
			"percent": roundi(_machine.get_stake_fraction() * 100.0),
		})
		if odds_label != null:
			# The printed odds are the odds this spin will actually roll, after drought
			# protection and after Bust suppression. The backend may protect the player
			# from ugly randomness; the readout may not misreport what it did.
			var odds := _machine.get_effective_odds()
			_authored.write_variant(odds_label, odds_live_template, {
				"jackpot": roundi(float(odds["positive"]) * 100.0),
				"bust": roundi(float(odds["triple_bust"]) * 100.0),
			})
	lever_grab.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if _machine.can_spin() else Control.CURSOR_ARROW
	)
	var lever_tint := Color(1.0, 1.0, 1.0) if _machine.can_spin() else Color(0.55, 0.6, 0.62)
	lever_up.modulate = lever_tint
	lever_down.modulate = lever_tint


func reel_window(reel_index: int) -> Control:
	match reel_index:
		0:
			return reel_one
		1:
			return reel_two
		_:
			return reel_three


func symbol_texture(symbol: int) -> Texture2D:
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


func advance_reels(delta: float) -> void:
	var moved := false
	for reel_index in range(3):
		var reel := reel_window(reel_index)
		if reel == null:
			continue
		if reel_index == 2 and _advance_rewind_reel(reel):
			# The third reel is running the fakeout, which drives its own position from
			# the stage the machine is in rather than free-scrolling. The result was
			# decided before any of this moved, so the animation can lie about the near
			# miss without the machine ever lying about the outcome.
			moved = true
			continue
		if _machine.is_reel_spinning(reel_index):
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
		elif _reel_offset[reel_index] != 0.0 or _machine.is_revealing():
			# Stopped. It lands on the face the machine already rolled, which is why the
			# reveal can be dramatic without being dishonest.
			_reel_offset[reel_index] = 0.0
			var landed := _machine.get_last_symbols()
			if reel_index < landed.size():
				_reel_symbol[reel_index] = landed[reel_index]
			moved = true
	if moved:
		refresh_reels()


func _capture_reel_rest_positions() -> void:
	for reel_index in range(3):
		var reel := reel_window(reel_index)
		if reel == null:
			continue
		var face_a := reel.get_node_or_null("FaceA") as Control
		var face_b := reel.get_node_or_null("FaceB") as Control
		if face_a != null:
			_reel_rest_a[reel_index] = face_a.position.y
		if face_b != null:
			_reel_rest_b[reel_index] = face_b.position.y


func _advance_rewind_reel(reel: Control) -> bool:
	# The winning face crosses the payline, keeps going, hangs there long enough to
	# read as a miss, and is then dragged back. Nothing here decides anything: the
	# symbol it snaps onto is the one the machine rolled before the lever finished
	# moving, which is what keeps the Easter egg an animation rather than a rig.
	var stage := _machine.get_rewind_stage()
	if stage == SlotMachine.RewindStage.NONE:
		return false
	var landed := _machine.get_last_symbols()
	if landed.size() < 3:
		return false
	var cell := maxf(1.0, reel.size.y)
	var fraction := _machine.get_rewind_stage_fraction()
	# The winning face is the one on the strip throughout, so the reversal brings back
	# the same symbol the player watched leave rather than substituting one in.
	_reel_symbol[2] = landed[2]
	match stage:
		SlotMachine.RewindStage.PASS:
			# Eased out, so it visibly decelerates as it goes past instead of sailing
			# through at spin speed: the slow is what makes the near miss legible.
			var eased := 1.0 - pow(1.0 - fraction, 2.4)
			_reel_offset[2] = cell * eased
		SlotMachine.RewindStage.HOLD:
			_reel_offset[2] = cell
		SlotMachine.RewindStage.SNAP:
			# Eased in: slow to start moving back, then hard into the stop, which is
			# what reads as a mechanical lock rather than a slide.
			_reel_offset[2] = cell * (1.0 - fraction * fraction)
	return true


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


func _on_lever_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not event.pressed:
		return
	pull_lever()


func pull_lever() -> void:
	if not _enabled:
		return
	if not _machine.try_spin(_player.get_arena_position()):
		if not _machine.is_buy_in_met():
			spin_refused.emit(
				"MINIMUM BUY-IN — %.1f / %.1f%% Established." % [
					_machine.get_established_fraction() * 100.0,
					_machine.minimum_buyin_established_fraction * 100.0,
				]
			)
		else:
			spin_refused.emit("The reels are still turning.")
		return
	# The committed region stops following the player and stops breathing. From here the
	# wager is world-fixed: the player may run anywhere, and the ground on the table is
	# the ground that was on the table when the lever went down.
	_wager_layer.set_wager_cells(_machine.get_committed_cells(), true)
	_lever_seated = true
	_lever_seat_remaining = lever_seat_seconds
	_refresh_lever()
	refresh_controls()
	spin_started.emit()


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


func _on_hover_changed(hovering: bool) -> void:
	# The preview is hover-only. Pulsing the wager region for the whole of a run would
	# put a permanent second overlay on the arena in service of a machine the player is
	# not currently thinking about.
	#
	# Counted rather than latched, because moving from the cabinet onto the stake meter
	# fires an exit and an enter in an order Godot does not promise, and a bare flag
	# would blink the region off and rebuild it every time the pointer crossed a seam.
	if not _enabled:
		return
	_hover_regions = maxi(0, _hover_regions + (1 if hovering else -1))
	_machine.set_preview_visible(_hover_regions > 0, _player.get_arena_position())


func _on_wager_changed(value: float) -> void:
	if not _enabled:
		return
	_machine.set_stake(int(round(value)))
	if _machine.is_preview_visible():
		# The region grows or shrinks through the organism as the notch moves, so the
		# stake is read as a shape before it is read as a percentage.
		_machine.set_preview_visible(false)
		_machine.set_preview_visible(true, _player.get_arena_position())
	refresh_controls()


func _advance_pair_focus(delta: float) -> void:
	if _pair_focus_remaining <= 0.0:
		return
	_pair_focus_remaining = maxf(0.0, _pair_focus_remaining - delta)
	if _pair_focus_is_cinematic:
		# The one thing that must keep moving while the world is held: the reels the
		# player is being asked to watch.
		_machine.advance(delta)
		advance_reels(delta)
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
	_apply_focus(lerpf(1.0, peak, focus))
	if _pair_focus_remaining > 0.0:
		return
	_apply_focus(1.0)
	if _pair_focus_is_cinematic:
		cinematic_ended.emit()
	_pair_focus_is_cinematic = false


func _apply_focus(focus_scale: float) -> void:
	# The panel is grown about its own centre and pulled inward, rather than being
	# reparented into a proxy: the machine keeps taking input the whole time, which it
	# would not if it were drawn somewhere it does not live.
	if not _panel_home_captured:
		_panel_home = Rect2(position, size)
		_panel_home_captured = true
	pivot_offset = _panel_home.size * 0.5
	scale = Vector2(focus_scale, focus_scale)
	var inset := pair_focus_inset_pixels * clampf(focus_scale - 1.0, 0.0, 4.0)
	position = _panel_home.position - Vector2(inset, 0.0)
