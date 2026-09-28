class_name Traffic
extends Node2D
## Passing traffic on the four-lane road. Each moving lane feeds its own
## stream of taxis, saloons, microbuses, pickups, tuk-tuks and delivery
## scooters, sometimes in little bunches. Vehicles keep their distance: one
## that catches a slower one brakes and follows it instead of driving through
## it. Y-sorted so nearer lanes pass in front of farther ones; WorldHost keeps
## it behind FIFI.

## Moving lanes (tile rows) and their direction: the two nearer lanes run the
## way FIFI faces (-u), the far lane comes the other way.
const LANES := [[-3.0, -1.0], [-6.5, -1.0], [-9.9, 1.0]]
## Vehicles enter and leave this many tiles either side of FIFI, off screen.
const START_U := 30.0
const MAX_VEHICLES := 7
## Clear road kept to the vehicle ahead: a fixed margin plus a time gap.
const MIN_GAP := 1.5
const TIME_GAP := 0.7
const ACCEL := 3.0
const BRAKE := 9.0

var _rng := RandomNumberGenerator.new()
## Seconds until each lane next tries to send a vehicle.
var _wait: Array[float] = [1.0, 3.0, 5.5]
var _ambient := Color.WHITE
var _darkness := 0.0
var _t := 0.0


func _ready() -> void:
	y_sort_enabled = true
	_rng.randomize()


func set_light(ambient: Color, darkness: float) -> void:
	_ambient = ambient
	_darkness = darkness
	for v in get_children():
		(v as StreetVehicle).set_light(ambient, darkness)


func _process(delta: float) -> void:
	_t += delta
	var cars: Array[StreetVehicle] = []
	for v in get_children():
		cars.append(v as StreetVehicle)
	for car in cars:
		var target := car.speed
		var leader := _leader(car, cars)
		if leader:
			var gap := _gap(car, leader)
			var safe := MIN_GAP + car.cur_speed * TIME_GAP
			if gap < safe:
				# Ease down toward the leader's speed, and below it when too close.
				target = minf(target, leader.cur_speed * clampf(gap / safe, 0.0, 1.0))
		var rate := ACCEL if target > car.cur_speed else BRAKE
		car.cur_speed = move_toward(car.cur_speed, target, rate * delta)
		if car.kind == StreetVehicle.Kind.TUKTUK or car.kind == StreetVehicle.Kind.SCOOTER:
			car.bob = sin(_t * 17.0 + car.lane_v * 3.1 + car.speed) * 1.3
		car.u += car.dir * car.cur_speed * delta
		if car.u * car.dir > START_U + car.length_tiles():
			car.queue_free()
	for i in LANES.size():
		_wait[i] -= delta
		if _wait[i] <= 0.0:
			# Mostly spaced out, now and then a bunch close behind.
			_wait[i] = _rng.randf_range(1.2, 2.2) if _rng.randf() < 0.35 else _rng.randf_range(4.0, 11.0)
			if cars.size() < MAX_VEHICLES and _entry_clear(i, cars):
				_spawn(i)


## The nearest vehicle ahead of `car` in its lane, if any.
func _leader(car: StreetVehicle, cars: Array[StreetVehicle]) -> StreetVehicle:
	var best: StreetVehicle = null
	var best_d := INF
	for other in cars:
		if other == car or other.lane_v != car.lane_v:
			continue
		var d := (other.u - car.u) * car.dir
		if d > 0.0 and d < best_d:
			best_d = d
			best = other
	return best


## Clear road between a vehicle's nose and the leader's tail, in tiles.
func _gap(car: StreetVehicle, leader: StreetVehicle) -> float:
	return (leader.u - car.u) * car.dir - (car.length_tiles() + leader.length_tiles()) * 0.5


func _entry_clear(lane: int, cars: Array[StreetVehicle]) -> bool:
	var v: float = LANES[lane][0]
	var d: float = LANES[lane][1]
	for car in cars:
		if car.lane_v == v and (car.u * d) < -START_U + car.length_tiles() + 6.0:
			return false
	return true


func _spawn(lane_index: int) -> void:
	var lane: Array = LANES[lane_index]
	var car := StreetVehicle.new()
	var roll := _rng.randf()
	# Tuk-tuks and scooters stick to the lane by the kerb.
	if lane_index == 0 and roll < 0.3:
		car.kind = StreetVehicle.Kind.TUKTUK if _rng.randf() < 0.6 else StreetVehicle.Kind.SCOOTER
	elif roll < 0.4:
		car.kind = StreetVehicle.Kind.TAXI
	elif roll < 0.68:
		car.kind = StreetVehicle.Kind.SEDAN
	elif roll < 0.88:
		car.kind = StreetVehicle.Kind.MICROBUS
	else:
		car.kind = StreetVehicle.Kind.PICKUP
	car.lane_v = lane[0]
	car.dir = lane[1]
	match car.kind:
		StreetVehicle.Kind.TUKTUK:
			car.speed = _rng.randf_range(2.2, 3.0)
		StreetVehicle.Kind.SCOOTER:
			car.speed = _rng.randf_range(4.5, 6.0)
		StreetVehicle.Kind.MICROBUS:
			car.speed = _rng.randf_range(4.8, 6.5)
		StreetVehicle.Kind.PICKUP:
			car.speed = _rng.randf_range(3.2, 4.2)
		_:
			car.speed = _rng.randf_range(3.8, 5.5)
	car.u = -car.dir * START_U
	add_child(car)
	car.set_light(_ambient, _darkness)
