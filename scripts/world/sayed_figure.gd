class_name SayedFigure
extends VoxPerson
## Sayed in his lawn chair between orders: checked shirt, the قهوجي's towel
## over his shoulder, moustache and stubble, a glass of tea in his hand. He
## breathes, looks up and down the street, and every so often lifts the
## glass for a sip.

var _sip := 0.0
var _next_sip := 5.0
var _rng2 := RandomNumberGenerator.new()


func _ready() -> void:
	_rng2.randomize()
	build(VoxPerson.sayed_look(), "sit")


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	rig.scale.y = 1.0 + 0.01 * sin(_t * TAU / 3.6)
	head.rotation.y = sin(_t * 0.23) * 0.45
	_next_sip -= delta
	if _next_sip <= 0.0:
		_next_sip = _rng2.randf_range(6.0, 11.0)
		var t := create_tween()
		t.tween_property(self, "_sip", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
		t.tween_interval(0.8)
		t.tween_property(self, "_sip", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	raise_arm(1, 0.35 + 0.55 * _sip)
	arms[0].rotation.x = -0.25
	head.rotation.x = -0.25 * _sip
