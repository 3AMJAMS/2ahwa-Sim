extends Node
## Persistent player economy. Owns the live SaveData and writes it back:
## at day end, after a purchase, and when the app is paused/closed
## (Android can kill a backgrounded app without warning).

signal currency_changed(new_amount: int)
signal upgrade_purchased(id: String)
signal day_advanced(day_number: int)

var data: SaveData

var currency_egp: int:
	get: return data.currency_egp
var current_venue_tier: int:
	get: return data.current_venue_tier
var owned_upgrades: Array[String]:
	get: return data.owned_upgrades
var unlocked_menu_items: Array[String]:
	get: return data.unlocked_menu_items
var day_number: int:
	get: return data.day_number


func _ready() -> void:
	data = SaveSystem.load_save()


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


func owns(id: String) -> bool:
	return id in data.owned_upgrades or bool(GameData.get_equipment(id).get("unlocked", false))


func end_day() -> void:
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
