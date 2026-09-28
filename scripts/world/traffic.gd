class_name Traffic
extends Node2D
## Passing traffic on the four-lane road: every few seconds a taxi, microbus
## or tuk-tuk drives through one of the three moving lanes. Y-sorted so nearer
## lanes pass in front of farther ones; WorldHost keeps it behind FIFI.

## Moving lanes (tile rows) and their direction: the two nearer lanes run the
## way FIFI faces (-u), the far lane comes the other way.
const LANES := [[-3.0, -1.0], [-6.5, -1.0], [-9.9, 1.0]]
const START_U := 24.0
const MAX_VEHICLES := 3

var _rng := RandomNumberGenerator.new()
var _wait := 1.5
var _ambient := Color.WHITE
var _darkness := 0.0


func _ready() -> void:
	y_sort_enabled = true
	_rng.randomize()


func set_light(ambient: Color, darkness: float) -> void:
	_ambient = ambient
	_darkness = darkness
	for v in get_children():
		(v as StreetVehicle).set_light(ambient, darkness)


func _process(delta: float) -> void:
	for v in get_children():
		var car := v as StreetVehicle
		car.u += car.dir * car.speed * delta
		if absf(car.u) > START_U + 1.0:
			car.queue_free()
	_wait -= delta
	if _wait <= 0.0:
		_wait = _rng.randf_range(3.5, 9.0)
		if get_child_count() < MAX_VEHICLES:
			_spawn()


func _spawn() -> void:
	var lane: Array = LANES[_rng.randi() % LANES.size()]
	var car := StreetVehicle.new()
	var roll := _rng.randf()
	car.kind = StreetVehicle.Kind.TAXI if roll < 0.45 else (StreetVehicle.Kind.MICROBUS if roll < 0.75 else StreetVehicle.Kind.TUKTUK)
	car.lane_v = lane[0]
	car.dir = lane[1]
	car.speed = _rng.randf_range(2.2, 3.0) if car.kind == StreetVehicle.Kind.TUKTUK else _rng.randf_range(3.5, 5.0)
	car.u = -car.dir * START_U
	add_child(car)
	car.set_light(_ambient, _darkness)
