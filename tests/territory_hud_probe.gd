extends SceneTree

## The territory bar has to say something it could not say before: whether the ground
## the run does not hold is available soil or enemy infrastructure, and how much of
## what it does hold has actually established. Those are the two readings the rework
## turns on, so they are worth pinning rather than eyeballing once.
##
## The bar's shape is no longer this component's business -- it draws the authored fill
## art and the shader tints it, so the silhouette matches by construction rather than
## by agreement. What is left to check is the geometry it publishes to the shader, the
## palette it publishes with, and that the scene is actually wired to the shader those
## numbers are written for. A uniform name that drifts between script and shader fails
## silently, which is exactly the sort of thing a probe should be holding.

## The Rot wash the field actually paints with, averaged off
## assets/textures/rot_wash_v3.png. The bar's Rot has to name the same material the
## battlefield does, so its hue is checked against this rather than against a number
## typed into the control. It is a desaturated plum; the bar used to draw a saturated
## pure red, which named nothing on screen.
const ROT_WASH_REFERENCE := Color(0.317, 0.161, 0.232)
## The authored territory_fill art, (131, 161, 88). The bar's Green is taken from it so
## this bar sits in the same palette as the health and XP bars beside it.
const TERRITORY_FILL_ART := Color(0.514, 0.631, 0.345)
const COMPOSITION_SHADER_PATH := "res://assets/shaders/territory_bar_composition.gdshader"
const RUN_SCENE_PATH := "res://scenes/run/phase_b_prototype.tscn"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var composition := PhaseBTerritoryComposition.new()
	composition.size = Vector2(220.0, 32.0)
	root.add_child(composition)

	# The doc's own two examples. They describe opposite strategic situations and the
	# bar must not render them alike.
	composition.set_composition(30.0, 60.0, 10.0, 0.0)
	var recoverable := _band_widths(composition)
	composition.set_composition(30.0, 10.0, 60.0, 0.0)
	var dangerous := _band_widths(composition)
	_check(
		is_equal_approx(recoverable.x, dangerous.x),
		"both situations hold the same Green (%.1f, %.1f)" % [recoverable.x, dangerous.x]
	)
	_check(
		absf(recoverable.z - dangerous.z) > composition.size.x * 0.25,
		"a Neutral board and a Rot board do not render alike (Rot %.1f vs %.1f)"
			% [recoverable.z, dangerous.z]
	)

	# The three shares are published against one total, so the zones must tile the bar
	# rather than leave a gap the eye has to interpret.
	composition.set_composition(30.0, 10.0, 60.0, 0.0)
	var widths := _band_widths(composition)
	_check(
		absf(widths.x + widths.y + widths.z - composition.size.x) < 0.51,
		"the three zones tile the whole bar (%.1f + %.1f + %.1f of %.1f)"
			% [widths.x, widths.y, widths.z, composition.size.x]
	)

	# Established Green is still published and still read by the hover; the bar simply
	# does not try to say it any more.
	composition.set_composition(50.0, 30.0, 20.0, 65.0)
	_check(
		is_equal_approx(composition.get_mature_fraction_of_green(), 65.0),
		"the established share is still carried even though the bar no longer draws it"
	)

	# Degenerate inputs must not push the shader past the ends of the bar.
	composition.set_composition(-20.0, 400.0, 900.0, 800.0)
	var clamped := _band_widths(composition)
	var clamped_edges := composition.get_colour_edges()
	_check(
		clamped.x >= 0.0
		and clamped.z <= composition.size.x + 0.001
		and _mature_width(composition) <= composition.size.x + 0.001
		and clamped_edges.x >= 0.0
		and clamped_edges.y <= 1.0,
		"out-of-range metrics stay inside the bar"
	)

	_test_colour_edges(composition)
	_test_palette(composition)
	_test_shader_contract(composition)
	_test_scene_wiring()

	if _failures > 0:
		push_error("TERRITORY_HUD: %d failure(s)" % _failures)
		quit(1)
		return
	print("TERRITORY_HUD: PASS")
	quit(0)


func _test_colour_edges(composition: PhaseBTerritoryComposition) -> void:
	## Where each colour ends is the only geometry this component still owns, so it is
	## what the bar's correctness now rests on.
	composition.set_composition(60.0, 20.0, 20.0, 50.0)
	var edges := composition.get_colour_edges()
	_check(
		is_equal_approx(edges.x, 0.60) and is_equal_approx(edges.y, 0.80),
		"the colours end where the shares put them (%.3f / %.3f)" % [edges.x, edges.y]
	)
	_check(edges.x <= edges.y, "the Green never overruns the Rot")
	# Rot is measured back from the right end, so it always finishes flush with the bar
	# even when the three published shares round imperfectly against each other.
	composition.set_composition(30.0, 9.0, 61.0, 0.0)
	var flush := composition.get_colour_edges()
	_check(
		is_equal_approx(flush.y, 0.39),
		"Rot reaches the end of the bar whatever the shares round to (%.3f)" % flush.y
	)
	# No empty span left when the two meet.
	composition.set_composition(40.0, 0.0, 60.0, 0.0)
	var touching := composition.get_colour_edges()
	_check(
		is_equal_approx(touching.x, touching.y),
		"with no open soil the two colours touch instead of leaving a gap"
	)


func _test_palette(composition: PhaseBTerritoryComposition) -> void:
	## Two colours and no more. The bar briefly carried four and that was too many
	## things to read at a glance on a strip thirty pixels tall.
	_check(
		_near(composition.green_color, TERRITORY_FILL_ART, 0.02),
		"held Green is taken from the authored bar art"
	)
	# Rot has to name what is actually on the field.
	_check(
		absf(composition.hostile_color.h - ROT_WASH_REFERENCE.h) < 0.04,
		"Rot on the bar is the same hue as the Rot on the field (%.3f vs %.3f)"
			% [composition.hostile_color.h, ROT_WASH_REFERENCE.h]
	)
	_check(
		absf(composition.hostile_color.s - ROT_WASH_REFERENCE.s) < 0.20,
		"Rot on the bar is as desaturated as the wash, not a pure red (%.3f vs %.3f)"
			% [composition.hostile_color.s, ROT_WASH_REFERENCE.s]
	)
	_check(
		composition.hostile_color.b > composition.hostile_color.g,
		"Rot leans purple rather than red"
	)
	# Counting Color properties would sweep up modulate and self_modulate from Control,
	# so the palette is checked by name: the two that remain, and the two that went.
	var script_colors := PackedStringArray()
	for property in composition.get_script().get_script_property_list():
		if property["type"] == TYPE_COLOR:
			script_colors.append(String(property["name"]))
	_check(
		script_colors.size() == 2
		and script_colors.has("green_color")
		and script_colors.has("hostile_color"),
		"the bar carries Green and Rot and nothing else (%s)" % ", ".join(script_colors)
	)


func _test_shader_contract(composition: PhaseBTerritoryComposition) -> void:
	## Every name the script pushes has to exist in the shader. set_shader_parameter on
	## a name the shader does not declare fails silently, so without this a renamed
	## uniform would simply stop colouring the bar with no error anywhere.
	var shader: Shader = load(COMPOSITION_SHADER_PATH)
	if shader == null:
		_check(false, "the composition shader loads")
		return
	var declared := {}
	for entry in shader.get_shader_uniform_list():
		declared[String(entry["name"])] = true
	# An empty list means the shader did not compile at all, which otherwise surfaces
	# only as every uniform appearing to be missing at once.
	_check(not declared.is_empty(), "the shader compiles")
	var pushed := [
		"bar_width_px",
		"green_edge",
		"hostile_edge",
		"blend_width",
		"green_color",
		"hostile_color",
	]
	var missing := PackedStringArray()
	for name in pushed:
		if not declared.has(name):
			missing.append(name)
	_check(
		missing.is_empty(),
		"the shader declares every uniform the script pushes (missing: %s)"
			% ", ".join(missing)
	)
	# The sloshing parameters are authored in the scene rather than pushed, so they
	# only need to exist for the materials to be tunable in the editor.
	for name in ["art_width_px", "cap_width_px", "top_shade", "bottom_shade"]:
		_check(declared.has(name), "the shader exposes %s for tuning" % name)
	# The bars are deliberately still. TIME anywhere in this shader would mean the
	# animated version had crept back in.
	var source := FileAccess.get_file_as_string(COMPOSITION_SHADER_PATH)
	var code := ""
	for line in source.split("
"):
		# Comment lines are stripped first, because the file says in prose that it does
		# not use TIME and a naive scan would trip over its own explanation.
		var comment := line.find("//")
		code += (line if comment < 0 else line.substr(0, comment)) + "
"
	_check(
		not code.contains("TIME"),
		"the bar shader does not animate"
	)


func _test_scene_wiring() -> void:
	## The scene is the design surface, so what it is actually wired to is part of what
	## has to hold. Health and XP are plain ProgressBars drawing their own authored
	## fills, with no shader and no child of any kind; only the territory bar needs a
	## component, because only it has two things to say along one bar.
	var packed: PackedScene = load(RUN_SCENE_PATH)
	if packed == null:
		_check(false, "the run scene loads")
		return
	var run := packed.instantiate()
	var panel := run.get_node_or_null("Interface/SidePanel")
	if panel == null:
		_check(false, "the side panel is where the bars live")
		run.free()
		return
	for bar_name in ["HealthBar", "XPBar"]:
		var bar := panel.get_node_or_null(bar_name) as ProgressBar
		if bar == null:
			_check(false, "%s exists" % bar_name)
			continue
		_check(
			bar.get_theme_stylebox("fill") is StyleBoxTexture,
			"%s draws its own authored fill again" % bar_name
		)
		_check(bar.material == null, "%s carries no shader" % bar_name)
		_check(
			bar.get_child_count() == 0,
			"%s has no overlay child left behind" % bar_name
		)
	var territory := panel.get_node_or_null("TerritoryBar") as ProgressBar
	if territory == null:
		_check(false, "TerritoryBar exists")
		run.free()
		return
	_check(
		territory.get_theme_stylebox("fill") is StyleBoxEmpty,
		"the territory bar leaves its fill to the composition"
	)
	var composition := territory.get_node_or_null("TerritoryComposition") as PhaseBTerritoryComposition
	if composition == null:
		_check(false, "the territory bar has its composition child")
		run.free()
		return
	var shader_material := composition.material as ShaderMaterial
	_check(
		shader_material != null
		and shader_material.shader != null
		and shader_material.shader.resource_path == COMPOSITION_SHADER_PATH,
		"the composition runs the composition shader"
	)
	_check(
		composition.fill_style is StyleBoxTexture,
		"the composition draws the authored fill art"
	)
	# The inner ends are stamped with the art's own cap, so the shader has to be told
	# where that cap lives. Hard-coding it would let a re-authored bar end up with inner
	# ends a different shape from its outer ones.
	composition.set_composition(50.0, 20.0, 30.0, 0.0)
	composition._refresh()
	var art := composition.fill_style as StyleBoxTexture
	var pushed_width: float = shader_material.get_shader_parameter("art_width_px")
	var pushed_cap: float = shader_material.get_shader_parameter("cap_width_px")
	_check(
		art != null
		and art.texture != null
		and is_equal_approx(pushed_width, float(art.texture.get_width()))
		and is_equal_approx(pushed_cap, art.texture_margin_left),
		"the cap the inner ends use is read off the art (%.0f px wide, %.0f px cap)"
			% [pushed_width, pushed_cap]
	)
	_check(
		pushed_cap > 1.0 and pushed_cap < pushed_width,
		"the cap is a real slice of the art rather than a degenerate one"
	)
	run.free()


func _near(a: Color, b: Color, tolerance: float = 0.06) -> bool:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) < tolerance


func _band_widths(composition: PhaseBTerritoryComposition) -> Vector3:
	## Green, Neutral, Rot in bar pixels, derived the way the control derives them so
	## the probe measures the same geometry that is drawn.
	var width := composition.size.x
	return Vector3(
		width * composition.get_player_percent() * 0.01,
		width * clampf(composition._neutral_percent, 0.0, 100.0) * 0.01,
		width * clampf(composition._hostile_percent, 0.0, 100.0) * 0.01
	)


func _mature_width(composition: PhaseBTerritoryComposition) -> float:
	var green_width := composition.size.x * composition.get_player_percent() * 0.01
	return green_width * composition.get_mature_fraction_of_green() * 0.01


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures += 1
	push_error("FAIL: %s" % description)
