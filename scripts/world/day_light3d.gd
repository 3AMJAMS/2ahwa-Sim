class_name DayLight3D
extends Node3D
## Sun, moon and sky for a 3D view, following DayClock: a warm low sun in the
## afternoon, orange at sunset, a dim blue moon after dark, and the ambient
## light and background colour to match. Sits in the street and in the prep
## station; the one whose view is showing drives the shared environment.

var sun := DirectionalLight3D.new()
var environment: Environment
## Degrees round the sky the light comes from (turns a little through the day).
@export var base_yaw := 35.0
@export var shadows := true
## Behind FIFI making a drink: after dark the street lamps' sodium glow is
## folded into the ambient light there instead of costing real lights.
var prep := false:
	set(on):
		prep = on
		apply()


func _ready() -> void:
	sun.shadow_enabled = shadows
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.5
	add_child(sun)
	var we := get_tree().get_first_node_in_group("world_env") as WorldEnvironment
	if we:
		environment = we.environment
	DayClock.minute_changed.connect(apply)
	apply()


func apply() -> void:
	if not is_visible_in_tree():
		return
	var h := DayClock.hour()
	var dark := DayClock.darkness()
	var amb := DayClock.ambient()
	var sky := DayClock.sky()
	# Afternoon sun swings west and sinks; after dark the moon stands higher.
	var day_k := clampf((h - 12.0) / 7.0, 0.0, 1.0)
	var pitch := lerpf(-58.0, -28.0, day_k)
	var yaw := base_yaw + lerpf(0.0, 25.0, day_k)
	var warm := Color(1.0, 0.96, 0.9).lerp(Color(1.0, 0.72, 0.45), smoothstep(16.5, 18.5, h) * (1.0 - smoothstep(18.8, 19.6, h)))
	var moon := Color(0.55, 0.62, 0.95)
	if dark > 0.5:
		pitch = -50.0
		yaw = base_yaw - 20.0
	sun.rotation_degrees = Vector3(pitch, yaw, 0)
	sun.light_color = warm.lerp(moon, dark)
	sun.light_energy = lerpf(1.35, 0.5, dark)
	# Moonlight shadows are faint and still cost a full shadow pass.
	sun.shadow_enabled = shadows and dark < 0.85
	if environment:
		environment.background_color = sky
		var ambient := Color(0.74, 0.78, 0.88).lerp(Color(0.42, 0.44, 0.74), dark) * amb.lerp(Color.WHITE, 0.5)
		if prep:
			ambient = ambient.lerp(Color(0.8, 0.6, 0.44), 0.5 * dark)
		environment.ambient_light_color = ambient
		environment.ambient_light_energy = lerpf(0.8, 1.35, dark)
