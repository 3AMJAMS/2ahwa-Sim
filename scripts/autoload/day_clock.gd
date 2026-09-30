extends Node
## In-game time of day. The clock starts each day in the late afternoon and
## keeps running (round the clock if need be) until the player taps "go home";
## scenes read the sky colour, ambient light and darkness from here.

signal minute_changed
## The shift is over (4 am): Sayed packs up and the day ends.
signal closing_time

## Sayed opens up in the late afternoon.
const START_HOUR := 16.0
## A shift runs from 4 pm to 4 am and takes this many real minutes; the
## day then ends by itself (the player can still go home earlier).
const SHIFT_HOURS := 12.0
const SHIFT_REAL_MINUTES := 15.0
## Game minutes per real second (0.8: sunset comes about 4 minutes in).
const MINUTES_PER_SECOND := SHIFT_HOURS * 60.0 / (SHIFT_REAL_MINUTES * 60.0)
## Lighting keyframes round the clock: hour, ambient tint, sky, darkness 0..1.
const KEYS := [
	[0.0, Color(0.62, 0.6, 0.76), Color("0e1022"), 1.0],
	[4.5, Color(0.62, 0.6, 0.76), Color("0e1022"), 1.0],
	[5.8, Color(0.78, 0.72, 0.8), Color("5a5a8a"), 0.6],
	[7.0, Color(0.96, 0.9, 0.86), Color("f0b98a"), 0.15],
	[8.5, Color(1, 1, 1), Color("8fc0e8"), 0.0],
	[16.5, Color(1, 1, 1), Color("8fc0e8"), 0.0],
	[17.6, Color(1.0, 0.88, 0.74), Color("f0a060"), 0.15],
	[18.5, Color(0.8, 0.68, 0.76), Color("6a4a7a"), 0.55],
	[19.5, Color(0.62, 0.6, 0.76), Color("0e1022"), 1.0],
	[24.0, Color(0.62, 0.6, 0.76), Color("0e1022"), 1.0],
]

## Minutes since midnight.
var minutes := START_HOUR * 60.0
## Game minutes since the shift started, and whether closing time was called.
var elapsed := 0.0
var _closed := false
var _last_whole := -1


func _process(delta: float) -> void:
	minutes = fmod(minutes + delta * MINUTES_PER_SECOND, 1440.0)
	elapsed += delta * MINUTES_PER_SECOND
	if not _closed and elapsed >= SHIFT_HOURS * 60.0:
		_closed = true
		closing_time.emit()
	var whole := int(minutes)
	if whole != _last_whole:
		_last_whole = whole
		RenderingServer.set_default_clear_color(sky())
		minute_changed.emit()


func start_day() -> void:
	minutes = START_HOUR * 60.0
	elapsed = 0.0
	_closed = false
	_last_whole = -1


func hour() -> float:
	return minutes / 60.0


## Tint for sunlit/lamplit surfaces: white at noon, cool and dim at night.
func ambient() -> Color:
	return _sample(1)


func sky() -> Color:
	return _sample(2)


## 0 in daylight, 1 at night: drives lamps, windows and LED glow.
func darkness() -> float:
	return _sample(3)


## "٤:٣٠ م" style, in five-minute steps.
func clock_text() -> String:
	var total := floori(minutes / 5.0) * 5
	var h := floori(total / 60.0)
	var m := total % 60
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%s:%s %s" % [GameData.ar_digits(h12), GameData.ar_digits(m).lpad(2, "٠"), "ص" if h < 12 else "م"]


func _sample(field: int) -> Variant:
	var h := hour()
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if h >= a[0] and h <= b[0]:
			var t: float = 0.0 if b[0] == a[0] else (h - a[0]) / (b[0] - a[0])
			var t2 := smoothstep(0.0, 1.0, t)
			if field == 3:
				return lerpf(a[3], b[3], t2)
			return (a[field] as Color).lerp(b[field], t2)
	return KEYS[0][field]
