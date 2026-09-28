class_name CustomerQueue
extends Node2D
## Brings customers to FIFI: every so often someone walks up the pavement to
## a free spot by the trunk, shouts an order and waits. Y-sorted so nearer
## customers overlap farther ones. While Sayed's first-serve tutorial is
## pending, only one customer comes, orders شاي كشري and waits forever.

signal customer_ordered(customer: Customer)
signal customer_left(customer: Customer, angry: bool)
signal customer_tapped(customer: Customer)
## A drink was handed over (the tutorial waits on this).
signal customer_served

## Where customers stand to order, along the pavement by the trunk (tiles).
const SLOTS := [Vector2(5.2, 4.7), Vector2(6.5, 4.7), Vector2(7.8, 4.7)]
## They walk in along the pavement from this far up the street.
const ENTRY_U := 17.0
const TUTORIAL_ORDER := "tea_koshari"

## Seconds between arrivals, and each customer's patience (Phase 3 swaps in
## per-archetype patience).
@export var arrival_gap := Vector2(12.0, 24.0)
@export var patience_range := Vector2(80.0, 110.0)

var open := true

var _rng := RandomNumberGenerator.new()
var _wait := 1.5
var _last_order := ""


func _ready() -> void:
	y_sort_enabled = true
	_rng.randomize()


func _process(delta: float) -> void:
	if not open:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = _rng.randf_range(arrival_gap.x, arrival_gap.y)
	var tutorial := Tutorial.pending("first_serve")
	if tutorial and not customers().is_empty():
		return
	var slot := _free_slot()
	if slot == -1:
		return
	var order := TUTORIAL_ORDER if tutorial else GameData.pick_order(_rng, _last_order)
	if order.is_empty():
		return
	_last_order = order
	_spawn(order, slot, tutorial)


func _spawn(order: String, slot: int, tutorial: bool) -> void:
	var c := Customer.new()
	var item := GameData.get_menu_item(order)
	var shouts: Array = item.get("shout_keys", [])
	var shout := tr(shouts[_rng.randi() % shouts.size()]) if not shouts.is_empty() else tr(item.get("name_key", order))
	c.setup(order, shout, _rng.randf_range(patience_range.x, patience_range.y), SLOTS[slot], ENTRY_U + slot * 1.3)
	c.patient = tutorial
	c.set_meta("slot", slot)
	add_child(c)
	c.ordered.connect(func() -> void: customer_ordered.emit(c))
	c.tapped.connect(func() -> void: customer_tapped.emit(c))
	c.left.connect(func(angry: bool) -> void:
		c.set_meta("slot", -1)
		customer_left.emit(c, angry))


## Everyone on the pavement who isn't walking away.
func customers() -> Array[Customer]:
	var out: Array[Customer] = []
	for c in get_children():
		if c is Customer and c.state != Customer.State.LEAVING:
			out.append(c)
	return out


## Customers who have ordered and are still waiting for their drink.
func waiting() -> Array[Customer]:
	var out: Array[Customer] = []
	for c in customers():
		if c.is_waiting():
			out.append(c)
	return out


## The order to make next: whoever has the least patience left.
func most_urgent() -> Customer:
	var best: Customer = null
	for c in waiting():
		if c.drink_ready:
			continue
		if best == null or c.patience < best.patience:
			best = c
	return best


## Day's over: everyone still here wanders off (no penalty).
func clear() -> void:
	for c in customers():
		c.leave(false)
	_wait = 2.0


func served(c: Customer) -> void:
	c.serve()
	customer_served.emit()


func _free_slot() -> int:
	var taken := {}
	for c in get_children():
		if c is Customer:
			taken[int(c.get_meta("slot", -1))] = true
	for i in SLOTS.size():
		if not taken.has(i):
			return i
	return -1
