extends "res://spd_point.gd"
## Room.Door from SPD Room.java at 2bb34a4e91d2.

enum Type {EMPTY, TUNNEL, WATER, REGULAR, UNLOCKED, HIDDEN, BARRICADE, LOCKED, CRYSTAL, WALL}

var type := Type.EMPTY
var _type_locked := false


func lock_type_changes(lock: bool) -> void:
	_type_locked = lock


func set_type(new_type: int) -> void:
	if not _type_locked and new_type > type:
		type = new_type


func store_in_bundle() -> Dictionary:
	return {"x": x, "y": y, "type": type, "type_locked": _type_locked}


func restore_from_bundle(bundle: Dictionary) -> void:
	x = int(bundle.get("x", 0))
	y = int(bundle.get("y", 0))
	type = int(bundle.get("type", Type.EMPTY))
	_type_locked = bool(bundle.get("type_locked", false))
