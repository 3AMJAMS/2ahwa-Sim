class_name SayedFigure
extends VoxPerson
## Sayed in his lawn chair between orders: checked shirt, the قهوجي's towel
## over his shoulder, moustache and stubble, a glass of tea in his hand. He
## breathes and keeps busy: sips his tea, nods along to the radio, fans
## himself, stretches, looks up and down the street, turns to see who's just
## walked up, and raises his glass when the player taps him.

var _sip := 0.0
var _fan := 0.0
var _stretch := 0.0
var _nodding := 0.0
var _next := 4.0
var _gaze := 0.0
var _gaze_left := 0.0
var _rng2 := RandomNumberGenerator.new()


func _ready() -> void:
	_rng2.randomize()
	build(VoxPerson.sayed_look(), "sit")


## Turns his head toward `at` (world point) for a few seconds.
func glance(at: Vector3, secs := 2.5) -> void:
	var d := to_local(at)
	_gaze = clampf(atan2(d.x, d.z), -1.3, 1.3)
	_gaze_left = secs


## Tapped: he lifts his glass to the player.
func cheers() -> void:
	_gaze = 0.0
	_gaze_left = 1.8
	var t := create_tween()
	t.tween_property(self, "_sip", 1.2, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.7)
	t.tween_property(self, "_sip", 0.0, 0.6).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	rig.scale.y = 1.0 + 0.01 * sin(_t * TAU / 3.6)
	_gaze_left -= delta
	_next -= delta
	if _next <= 0.0:
		_next = _rng2.randf_range(5.0, 10.0)
		var t := create_tween()
		match _rng2.randi() % 5:
			0, 1:
				t.tween_property(self, "_sip", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
				t.tween_interval(0.8)
				t.tween_property(self, "_sip", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
			2:
				# The radio's playing something he likes.
				t.tween_property(self, "_nodding", 1.0, 0.4)
				t.tween_interval(3.5)
				t.tween_property(self, "_nodding", 0.0, 0.6)
			3:
				t.tween_property(self, "_fan", 1.0, 0.4)
				t.tween_interval(2.2)
				t.tween_property(self, "_fan", 0.0, 0.5)
			4:
				t.tween_property(self, "_stretch", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
				t.tween_interval(0.6)
				t.tween_property(self, "_stretch", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	var look := _gaze if _gaze_left > 0.0 else sin(_t * 0.23) * 0.45
	head.rotation.y = lerp_angle(head.rotation.y, look, minf(1.0, delta * 4.0))
	head.rotation.x = -0.25 * minf(_sip, 1.0) + _nodding * 0.12 * sin(_t * 7.0) - 0.15 * _stretch
	# Right hand: the tea glass; left hand: fanning or resting on his knee.
	raise_arm(1, 0.35 + 0.55 * _sip + 0.5 * _stretch)
	arms[0].rotation.x = lerpf(-0.25, -2.0, maxf(_fan * 0.8, _stretch))
	arms[0].rotation.z = -0.35 * _fan + sin(_t * 12.0) * 0.25 * _fan
