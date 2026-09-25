extends SceneTree

const SpdRandom = preload("res://spd_random.gd")
const SpdActorClock = preload("res://spd_actor_clock.gd")
const Run = preload("res://run.gd")
const SpdSave = preload("res://spd_save.gd")


func _initialize() -> void:
	var rng = SpdRandom.new(0)
	var expected := [-1155484576, -723955400, 1033096058]
	for value in expected:
		if rng.next_int32() != value:
			_fail("java.util.Random(0) int sequence differs")
			return
	rng.reset(0)
	if absf(rng.randf() - 0.7309677600860596) > 0.00000001:
		_fail("java.util.Random(0) float sequence differs")
		return
	rng.reset(0)
	if rng.next_long() != -4962768465676381896:
		_fail("java.util.Random(0) long sequence differs")
		return
	rng.reset(0)
	var snapshot: Array[int] = rng.state_snapshot()
	rng.push_generator(42)
	for value in [1401063526, 1370585390, 403431633]:
		if rng.next_int(0x7FFFFFFF) != value:
			_fail("watabou Random's MX3 seed stack differs")
			return
	rng.pop_generator()
	if rng.next_int32() != expected[0] or not rng.restore_state(snapshot):
		_fail("Random stack pop/restore differs")
		return

	var clock = SpdActorClock.new()
	clock.add(0, SpdActorClock.HERO_PRIORITY)
	clock.add(1, SpdActorClock.MOB_PRIORITY)
	if clock.peek_actor() != 0:
		_fail("hero priority does not win time ties")
		return
	clock.spend(0, 1.0)
	if clock.next_actor() != 1:
		_fail("mob did not act after hero spent time")
		return
	clock.spend(1, 0.5)
	if clock.next_actor() != 1:
		_fail("speed-two mob did not get its second action")
		return
	clock.spend(1, 0.5)
	if clock.next_actor() != 0 or clock.now != 1.0:
		_fail("hero did not regain priority at the next whole tick")
		return
	var saved_clock: Dictionary = clock.snapshot()
	clock.remove(1)
	if not clock.restore(saved_clock) or not clock.has(1):
		_fail("actor clock snapshot did not round-trip")
		return

	var run = Run.new()
	run.start(42)
	if not run.clock.has(0) or run.clock.actor_time(0) != 0.0:
		_fail("new run lacks a scheduled hero")
		return
	run.mobs.clear()
	run.clock.clear()
	run.clock.add(0, SpdActorClock.HERO_PRIORITY)
	run.clock.add(1, SpdActorClock.MOB_PRIORITY)
	var adjacent := Vector2i.ZERO
	for direction in Run.DIRS8:
		if not Run.is_wall_tile(run.tile_at(run.hero + direction)) \
				and run.tile_at(run.hero + direction) != Run.CLOSED_DOOR:
			adjacent = direction
			break
	if adjacent == Vector2i.ZERO:
		_fail("scheduler test has no adjacent cell")
		return
	var cell: Vector2i = run.hero + adjacent
	run.mobs.append({"id": 1, "kind": "crab", "pos": cell, "hp": 15,
		"state": "hunting", "enemy_seen": true, "target": run.hero})
	run.wait_turn()
	if run.clock.actor_time(1) != 1.0 or run.clock.now != 1.0:
		_fail("run did not schedule two crab actions before the next hero turn")
		return
	var saved_run: Dictionary = run.snapshot()
	var restored = Run.new()
	if not restored.restore_snapshot(saved_run) or restored.hero != run.hero \
			or restored.depth != run.depth or restored.turns != run.turns \
			or restored.mobs.size() != run.mobs.size() \
			or restored.clock.snapshot() != run.clock.snapshot() \
			or restored.rng.state_snapshot() != run.rng.state_snapshot():
		_fail("run state did not round-trip with actor times and RNG")
		return
	if restored.rng.next_int32() != run.rng.next_int32():
		_fail("restored run did not continue the RNG sequence")
		return
	if SpdSave.restore_text(restored, "{\"version\":999,\"run\":{}}"):
		_fail("future save version was accepted")
		return
	if not SpdSave.save(run, 6):
		_fail("sixth save slot could not be written")
		return
	var disk_loaded = Run.new()
	if not SpdSave.load(disk_loaded, 6) or disk_loaded.turns != run.turns \
			or disk_loaded.hero != run.hero or disk_loaded.rng.state_snapshot() != run.rng.state_snapshot():
		_fail("save slot could not be resumed from disk")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SpdSave.slot_path(6)))
	run.depth = 2
	run._build_floor()
	if not SpdSave.save(run, 6) or not SpdSave.load(disk_loaded, 6) \
			or disk_loaded.depth != 2 or disk_loaded.stairs != run.stairs:
		_fail("new floor state did not survive a save/resume")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SpdSave.slot_path(6)))
	print("SPD foundation passed: Java RNG, actor scheduling, save/resume")
	quit()


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
