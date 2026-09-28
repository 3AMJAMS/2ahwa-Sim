extends Node
## TutorialManager: Sayed's diegetic walkthroughs, each played once and then
## remembered in SaveData.tutorials_seen (see technical-blueprint §8).
##   ui_intro     — first launch, on the street: day/clock/wallet, going home,
##                  tapping FIFI's trunk.
##   first_prep   — first order: reading it, picking ingredients, the tool.
##   hot_station  — first time on the stove: when to take it off the fire.
##   cold_station — first time on the blender: turbo and the motor cut-out.
##   first_tips   — first drink served: where the tips go.
## Scenes build the steps (they know where things are) and await play().
## A step is {"text": String, "target": Callable -> Rect2 (optional),
## "until": Signal (optional)}. Without "until" the player taps to go on;
## with it, taps inside the spotlight reach the game and the step ends when
## the signal fires. "Skip" turns every tutorial off for this save.

signal _advance

const LAYER := 8

var _overlay: CoachOverlay
var _token := 0
var _skipped_now := false


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	add_child(layer)
	_overlay = CoachOverlay.new()
	layer.add_child(_overlay)
	_overlay.tapped.connect(_on_tapped)
	_overlay.skip_pressed.connect(skip_all)


## True while this tutorial hasn't been seen (and tutorials aren't skipped).
func pending(id: String) -> bool:
	var seen := Economy.data.tutorials_seen
	return not bool(seen.get(id, false)) and not bool(seen.get("skipped", false))


func mark(id: String) -> void:
	Economy.data.tutorials_seen[id] = true
	Economy.save()


func is_playing() -> bool:
	return _overlay.visible


## Plays the steps in order; returns when they're done or skipped.
func play(steps: Array) -> void:
	_skipped_now = false
	_overlay.open()
	for step in steps:
		if _skipped_now:
			break
		# Let containers settle so the target rect is where it'll be seen.
		await get_tree().process_frame
		await get_tree().process_frame
		var target := Rect2()
		if step.has("target"):
			target = (step.target as Callable).call()
		var until: Signal = step.get("until", Signal())
		_overlay.show_step(step.text, target, not until.is_null())
		_token += 1
		var token := _token
		if until.is_null():
			await _advance
		else:
			var done := func() -> void:
				if token == _token:
					_advance.emit()
			until.connect(done, CONNECT_ONE_SHOT)
			await _advance
			if until.is_connected(done):
				until.disconnect(done)
	_overlay.close()


func skip_all() -> void:
	_skipped_now = true
	Economy.data.tutorials_seen["skipped"] = true
	Economy.save()
	_advance.emit()


func _on_tapped() -> void:
	_advance.emit()
