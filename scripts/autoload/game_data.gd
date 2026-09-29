extends Node
## Read-only game content loaded from data/*.json (menu, equipment, venues).
## Designers edit the JSON; scripts look things up here by id.

const MENU_PATH := "res://data/menu_items.json"
const EQUIPMENT_PATH := "res://data/equipment.json"
const VENUES_PATH := "res://data/venues.json"
const PREP_ITEMS_PATH := "res://data/prep_items.json"
const LOCALE := "ar_EG"

var menu_items: Dictionary = {}   # id -> item dict
var equipment: Dictionary = {}    # id -> equipment dict
var venues: Array = []            # index == venue tier id
## What the player picks from at the prep station, in display order.
var ingredients: Array = []       # [{id, name_key}]
var tools: Array = []             # [{id, name_key, station}]


func _ready() -> void:
	# Arabic is the base language; force it so devices set to English still
	# show the game in Ammiya. The English toggle arrives in Phase 6.
	TranslationServer.set_locale(LOCALE)
	for item in _load_list(MENU_PATH, "menu_items"):
		menu_items[item.id] = item
	for eq in _load_list(EQUIPMENT_PATH, "equipment"):
		equipment[eq.id] = eq
	venues = _load_list(VENUES_PATH, "venues")
	ingredients = _load_list(PREP_ITEMS_PATH, "ingredients")
	tools = _load_list(PREP_ITEMS_PATH, "tools")


func get_menu_item(id: String) -> Dictionary:
	return menu_items.get(id, {})


## Random orderable item: unlocked at the current venue tier, with its station
## slot owned. Avoids repeating avoid_id when there's anything else to pick.
func pick_order(rng: RandomNumberGenerator, avoid_id := "") -> String:
	var pool: Array[String] = []
	for id in menu_items:
		var item: Dictionary = menu_items[id]
		if int(item.get("unlock_tier", 0)) <= Economy.current_venue_tier \
				and Economy.owns_slot(item.get("station", "")):
			pool.append(id)
	if pool.size() > 1:
		pool.erase(avoid_id)
	return pool[rng.randi() % pool.size()] if not pool.is_empty() else ""


## The ingredient cards worth showing: those some orderable drink uses.
func menu_ingredients() -> Array:
	var used := {}
	for id in menu_items:
		var item: Dictionary = menu_items[id]
		if int(item.get("unlock_tier", 0)) <= Economy.current_venue_tier and Economy.owns_slot(item.get("station", "")):
			for ing in item.get("ingredients", []):
				used[ing] = true
	return ingredients.filter(func(e: Dictionary) -> bool: return used.has(e.id))


## The tool a station's drinks are made with ("heat" → the stove).
func tool_for_station(station: String) -> String:
	for t in tools:
		if t.get("station", "") == station:
			return t.id
	return ""


## Tools the player owns the station slot for, in display order.
func owned_tools() -> Array:
	return tools.filter(func(t: Dictionary) -> bool: return Economy.owns_slot(t.get("station", "")))


## Display name of an ingredient or tool id.
func prep_item_name(id: String) -> String:
	for entry in ingredients + tools:
		if entry.id == id:
			return tr(entry.name_key)
	return id


func get_equipment(id: String) -> Dictionary:
	return equipment.get(id, {})


func get_venue(tier: int) -> Dictionary:
	if tier >= 0 and tier < venues.size():
		return venues[tier]
	return {}


func price_for(item_id: String, venue_tier: int) -> float:
	var item := get_menu_item(item_id)
	var venue := get_venue(venue_tier)
	return float(item.get("base_price_egp", 0)) * float(venue.get("price_multiplier", 1.0))


## Formats an integer with Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩).
static func ar_digits(value: int) -> String:
	const DIGITS := "٠١٢٣٤٥٦٧٨٩"
	var out := ""
	for ch in str(value):
		out += DIGITS[int(ch)] if ch >= "0" and ch <= "9" else ch
	return out


func _load_list(path: String, key: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GameData: cannot open %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has(key):
		push_error("GameData: %s is missing top-level key '%s'" % [path, key])
		return []
	return parsed[key]
