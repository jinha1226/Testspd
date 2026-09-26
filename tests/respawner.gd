extends SceneTree

const Run = preload("res://run.gd")


func _initialize() -> void:
	var run = Run.new()
	run.start(31)
	run.depth = 2
	run._build_floor()
	for mob in run.mobs:
		run.clock.remove(mob["id"])
	run.mobs.clear()
	for _turn in range(49):
		run.wait_turn()
	if not run.mobs.is_empty():
		_fail("a regular mob respawned before its 50-turn cooldown")
		return
	var restored = Run.new()
	if not restored.restore_snapshot(run.snapshot()):
		_fail("regular floor could not restore its respawner state")
		return
	for _turn in range(3):
		run.wait_turn()
		restored.wait_turn()
	if run.snapshot() != restored.snapshot():
		_fail("respawn and mob rotation diverged after save/restore")
		return
	if run.mobs.size() != 1 or run.mobs[0]["state"] != "wandering":
		_fail("MobSpawner did not create a wandering replacement")
		return
	var cell: Vector2i = run.mobs[0]["pos"]
	if run.is_visible(cell) or run._distance_from_hero()[run._index(cell)] < 12:
		_fail("respawn ignored hero visibility or the twelve-step distance")
		return
	print("SPD respawner passed: cooldown, placement, wandering, save/restore")
	quit()


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
