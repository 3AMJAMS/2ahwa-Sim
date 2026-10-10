extends Node
## Persistent player economy. Owns the live SaveData and writes it back:
## at day end, after a purchase, and when the app is paused/closed
## (Android can kill a backgrounded app without warning).

signal currency_changed(new_amount: int)
signal upgrade_purchased(id: String)
signal day_advanced(day_number: int)

var data: SaveData
## Today's orders (not saved; shown on the day summary, and fed to
## telemetry once PostHog is in, Phase B).
var served_today := 0
var failed_today := 0

var currency_egp: int:
	get: return data.currency_egp
var current_venue_tier: int:
	get: return data.current_venue_tier
## Owned upgrades this build knows (see _fit_to_content()).
var owned_upgrades: Array[String]:
	get: return _known(data.owned_upgrades, GameData.equipment)
## Unlocked drinks this build knows.
var unlocked_menu_items: Array[String]:
	get: return _known(data.unlocked_menu_items, GameData.menu_items)
var day_number: int:
	get: return data.day_number


func _ready() -> void:
	data = SaveSystem.load_save()
	_fit_to_content()


## A save can name content this build doesn't have: a venue tier, an
## upgrade or a drink that was parked for a later phase (later/README.md),
## or one from a newer build. The tier is pulled into the range of venues
## that exist (no venue means no price multiplier, which would overcharge);
## unknown upgrade and drink ids stay in the save untouched, so they're still
## there when that content returns, but count for nothing here (see owns()
## and the getters above). Rack spots are handled the same way by PrepRig.
func _fit_to_content() -> void:
	var last := maxi(GameData.venues.size() - 1, 0)
	var tier := clampi(data.current_venue_tier, 0, last)
	if tier != data.current_venue_tier:
		push_warning("Economy: saved venue tier %d isn't in this build; using %d" % [data.current_venue_tier, tier])
		data.current_venue_tier = tier


static func _known(ids: Array[String], table: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id in ids:
		if table.has(id):
			out.append(id)
	return out


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()


func add_tips(amount: int) -> void:
	if amount <= 0:
		return
	data.currency_egp += amount
	currency_changed.emit(data.currency_egp)


func can_afford(cost: int) -> bool:
	return data.currency_egp >= cost


## Buys an item from data/equipment.json. Returns false if unknown,
## already owned, or unaffordable.
func purchase_upgrade(id: String) -> bool:
	var eq := GameData.get_equipment(id)
	if eq.is_empty() or id in data.owned_upgrades:
		return false
	var cost := int(eq.get("cost_egp", 0))
	if not can_afford(cost):
		return false
	data.currency_egp -= cost
	data.owned_upgrades.append(id)
	currency_changed.emit(data.currency_egp)
	upgrade_purchased.emit(id)
	save()
	return true


## Owned, or free from the start. Ids this build doesn't know are never owned.
func owns(id: String) -> bool:
	var eq := GameData.get_equipment(id)
	if eq.is_empty():
		return false
	return id in data.owned_upgrades or bool(eq.get("unlocked", false))


## True if any equipment for this station slot (e.g. "heat") is owned.
func owns_slot(slot: String) -> bool:
	for id in GameData.equipment:
		if GameData.equipment[id].get("slot", "") == slot and owns(id):
			return true
	return false


func record_order(served: bool) -> void:
	if served:
		served_today += 1
	else:
		failed_today += 1


func end_day() -> void:
	served_today = 0
	failed_today = 0
	data.day_number += 1
	day_advanced.emit(data.day_number)
	save()


func save() -> void:
	if data:
		SaveSystem.save(data)


## Debug helper: wipe progress.
func reset() -> void:
	SaveSystem.delete_save()
	data = SaveData.new()
	currency_changed.emit(data.currency_egp)
