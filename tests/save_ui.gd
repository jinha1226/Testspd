extends SceneTree

const Run = preload("res://run.gd")
const Main = preload("res://main.gd")
const SpdSave = preload("res://spd_save.gd")


func _initialize() -> void:
	var run = Run.new()
	run.start(9876)
	run.mobs.clear()
	run.wait_turn()
	if not SpdSave.save(run, 1):
		_fail("could not prepare save slot one")
		return
	var screen = Main.new()
	root.add_child(screen)
	call_deferred("_check_screen", screen, run.turns, run.hero)


func _check_screen(screen: Control, expected_turns: int, expected_hero: Vector2i) -> void:
	if screen.run.turns != expected_turns or screen.run.hero != expected_hero:
		_fail("main scene did not resume saved play")
		return
	screen._on_wait()
	var saved = Run.new()
	if not SpdSave.load(saved, 1) or saved.turns != expected_turns + 1:
		_fail("main scene did not autosave the next action")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SpdSave.slot_path(1)))
	print("SPD save UI passed: resume and autosave")
	quit()


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
