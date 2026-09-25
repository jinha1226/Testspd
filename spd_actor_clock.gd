extends RefCounted
## Deterministic single-threaded port of Actor's time and priority selection.
## Godot UI can yield between commands; simulation processes until the hero acts.

const HERO_PRIORITY := 0
const BLOB_PRIORITY := -10
const MOB_PRIORITY := -20
const BUFF_PRIORITY := -30

var now := 0.0
var _actors: Dictionary = {}


func clear() -> void:
	now = 0.0
	_actors.clear()


func add(actor_id: int, priority: int, delay: float = 0.0) -> void:
	_actors[actor_id] = {"time": now + maxf(delay, 0.0), "priority": priority}


func remove(actor_id: int) -> void:
	_actors.erase(actor_id)


func has(actor_id: int) -> bool:
	return _actors.has(actor_id)


func spend(actor_id: int, amount: float) -> void:
	if not _actors.has(actor_id):
		return
	var actor: Dictionary = _actors[actor_id]
	var next_time: float = float(actor["time"]) + amount
	if absf(fmod(next_time, 1.0)) < 0.001:
		next_time = roundf(next_time)
	actor["time"] = next_time
	_actors[actor_id] = actor


func actor_time(actor_id: int) -> float:
	return float(_actors[actor_id]["time"]) if _actors.has(actor_id) else INF


func peek_actor() -> int:
	var chosen := -1
	var earliest := INF
	var priority := -999999
	for actor_id in _actors:
		var entry: Dictionary = _actors[actor_id]
		var time: float = entry["time"]
		var rank: int = entry["priority"]
		if time < earliest or (time == earliest and rank > priority) \
				or (time == earliest and rank == priority and (chosen < 0 or actor_id < chosen)):
			chosen = actor_id
			earliest = time
			priority = rank
	return chosen


func next_actor() -> int:
	var actor_id := peek_actor()
	if actor_id >= 0:
		now = actor_time(actor_id)
	return actor_id


func snapshot() -> Dictionary:
	return {"now": now, "actors": _actors.duplicate(true)}


func restore(saved: Dictionary) -> bool:
	if not saved.has("now") or not saved.has("actors") or typeof(saved["actors"]) != TYPE_DICTIONARY:
		return false
	var restored: Dictionary = {}
	for key in saved["actors"]:
		var entry = saved["actors"][key]
		if typeof(entry) != TYPE_DICTIONARY or not entry.has("time") or not entry.has("priority"):
			return false
		restored[int(key)] = {"time": float(entry["time"]), "priority": int(entry["priority"])}
	now = float(saved["now"])
	_actors = restored
	return true
