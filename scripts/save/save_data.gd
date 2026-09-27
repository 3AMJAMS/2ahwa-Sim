class_name SaveData
extends Resource
## Versioned player save. Bump CURRENT_VERSION and add a step to
## SaveSystem.migrate() whenever a field is added, renamed or re-typed.

const CURRENT_VERSION := 1

@export var save_version: int = CURRENT_VERSION
@export var day_number: int = 1
@export var currency_egp: int = 0
@export var current_venue_tier: int = 0
@export var current_vehicle_id: String = "fifi"
@export var owned_upgrades: Array[String] = []
@export var unlocked_menu_items: Array[String] = ["tea_koshari"]
@export var seasonal_event_state: Dictionary = {}
@export var tutorials_seen: Dictionary = {}
@export var settings: Dictionary = {"skip_cutscenes": false, "auto_skip_after_day": 3}


func to_dict() -> Dictionary:
	return {
		"save_version": save_version,
		"day_number": day_number,
		"currency_egp": currency_egp,
		"current_venue_tier": current_venue_tier,
		"current_vehicle_id": current_vehicle_id,
		"owned_upgrades": owned_upgrades,
		"unlocked_menu_items": unlocked_menu_items,
		"seasonal_event_state": seasonal_event_state,
		"tutorials_seen": tutorials_seen,
		"settings": settings,
	}


static func from_dict(d: Dictionary) -> SaveData:
	var data := SaveData.new()
	data.save_version = int(d.get("save_version", 1))
	data.day_number = int(d.get("day_number", data.day_number))
	data.currency_egp = int(d.get("currency_egp", data.currency_egp))
	data.current_venue_tier = int(d.get("current_venue_tier", data.current_venue_tier))
	data.current_vehicle_id = str(d.get("current_vehicle_id", data.current_vehicle_id))
	data.owned_upgrades.assign(d.get("owned_upgrades", []))
	data.unlocked_menu_items.assign(d.get("unlocked_menu_items", data.unlocked_menu_items))
	data.seasonal_event_state = d.get("seasonal_event_state", {})
	data.tutorials_seen = d.get("tutorials_seen", {})
	data.settings = d.get("settings", data.settings)
	return data
