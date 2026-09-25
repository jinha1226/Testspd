extends Control

const Run = preload("res://run.gd")
const SpdSave = preload("res://spd_save.gd")
const TILE_TEXTURE = preload("res://assets/tiles_sewers.png")
const HERO_TEXTURE = preload("res://assets/warrior.png")
const RAT_TEXTURE = preload("res://assets/rat.png")
const SNAKE_TEXTURE = preload("res://assets/snake.png")
const GNOLL_TEXTURE = preload("res://assets/gnoll.png")
const SWARM_TEXTURE = preload("res://assets/swarm.png")
const CRAB_TEXTURE = preload("res://assets/crab.png")
const SLIME_TEXTURE = preload("res://assets/slime.png")
const ITEM_TEXTURE = preload("res://assets/items.png")
const UI_FONT = preload("res://assets/fonts/Galmuri11.ttf")
const CELL_SIZE := 32.0
const MAP_TOP := 88.0
const MAP_BOTTOM_MARGIN := 166.0

var run = Run.new()
var status_label: Label
var message_label: Label
var wait_button: Button
var potion_button: Button
var restart_button: Button
var auto_path: Array[Vector2i] = []
var auto_elapsed := 0.0
var autosave_enabled := true
var save_failed := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var ui_theme := Theme.new()
	ui_theme.default_font = UI_FONT
	theme = ui_theme
	if SpdSave.exists(1):
		if not SpdSave.load(run, 1):
			run.start()
			autosave_enabled = false
			run.message = "저장 파일을 읽지 못했습니다. 새 게임을 누르면 새로 저장합니다."
	else:
		run.start()
	_create_ui()
	_layout_ui()
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_instance_valid(status_label):
		_layout_ui()
		queue_redraw()


func _create_ui() -> void:
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color(0.93, 0.87, 0.72))
	status_label.add_theme_font_size_override("font_size", 20)
	add_child(status_label)
	message_label = Label.new()
	message_label.add_theme_color_override("font_color", Color(0.75, 0.79, 0.72))
	message_label.add_theme_font_size_override("font_size", 15)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(message_label)
	wait_button = _button("대기", _on_wait)
	potion_button = _button("물약", _on_potion)
	restart_button = _button("새 게임", _on_restart)


func _button(caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(95, 48)
	button.pressed.connect(callback)
	add_child(button)
	return button


func _layout_ui() -> void:
	status_label.position = Vector2(12, 12)
	status_label.size = Vector2(size.x - 24, 28)
	message_label.position = Vector2(12, 45)
	message_label.size = Vector2(size.x - 24, 37)
	var width := (size.x - 40.0) / 3.0
	for index in range(3):
		var button: Button = [wait_button, potion_button, restart_button][index]
		button.position = Vector2(10.0 + index * (width + 10.0), size.y - 72.0)
		button.size = Vector2(width, 52)


func _board_rows() -> int:
	return maxi(1, int((size.y - MAP_TOP - MAP_BOTTOM_MARGIN) / CELL_SIZE))


func _board_cols() -> int:
	return maxi(1, int(size.x / CELL_SIZE))


func _camera_origin() -> Vector2i:
	var cols := _board_cols()
	var rows := _board_rows()
	return Vector2i(
		clampi(run.hero.x - int(cols / 2), 0, maxi(0, Run.WIDTH - cols)),
		clampi(run.hero.y - int(rows / 2), 0, maxi(0, Run.HEIGHT - rows))
	)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.03, 0.035))
	var cols := _board_cols()
	var rows := _board_rows()
	var camera := _camera_origin()
	var left := (size.x - cols * CELL_SIZE) * 0.5
	draw_rect(
		Rect2(left, MAP_TOP, cols * CELL_SIZE, rows * CELL_SIZE),
		Color(0.045, 0.055, 0.06)
	)
	for y in range(rows):
		for x in range(cols):
			var cell := camera + Vector2i(x, y)
			var destination := Rect2(
				Vector2(left + x * CELL_SIZE, MAP_TOP + y * CELL_SIZE),
				Vector2(CELL_SIZE, CELL_SIZE)
			)
			if not run.is_explored(cell):
				continue
			var tile_id := _visual_tile(cell)
			var source := Rect2(
				Vector2((tile_id % 16) * 16, int(tile_id / 16) * 16),
				Vector2(16, 16)
			)
			var tint := Color.WHITE if run.is_visible(cell) else Color(0.34, 0.39, 0.42)
			draw_texture_rect_region(TILE_TEXTURE, destination, source, tint)
			if run.is_visible(cell):
				if run.potions.has(cell):
					_draw_sprite(ITEM_TEXTURE, Rect2(0, 22 * 16, 16, 16), destination)
				for mob in run.mobs:
					if mob["pos"] == cell:
						_draw_mob(mob["kind"], destination)
						break
			if cell == run.hero:
				var hero_destination := Rect2(
					destination.position + Vector2(4, 2),
					Vector2(24, 30)
				)
				draw_texture_rect_region(
					HERO_TEXTURE, hero_destination, Rect2(0, 0, 12, 15)
				)
	draw_line(
		Vector2(0, MAP_TOP + rows * CELL_SIZE + 9),
		Vector2(size.x, MAP_TOP + rows * CELL_SIZE + 9),
		Color(0.37, 0.34, 0.25)
	)


func _draw_mob(kind: String, cell: Rect2) -> void:
	match kind:
		"snake":
			_draw_sprite(SNAKE_TEXTURE, Rect2(0, 0, 12, 11),
				Rect2(cell.position + Vector2(4, 6), Vector2(24, 22)))
		"gnoll":
			_draw_sprite(GNOLL_TEXTURE, Rect2(0, 0, 12, 15),
				Rect2(cell.position + Vector2(4, 2), Vector2(24, 30)))
		"swarm":
			_draw_sprite(SWARM_TEXTURE, Rect2(0, 0, 16, 16), cell)
		"crab":
			_draw_sprite(CRAB_TEXTURE, Rect2(0, 0, 16, 16), cell)
		"slime":
			_draw_sprite(SLIME_TEXTURE, Rect2(0, 0, 14, 12),
				Rect2(cell.position + Vector2(2, 4), Vector2(28, 24)))
		_:
			_draw_sprite(RAT_TEXTURE, Rect2(0, 0, 16, 15), cell)


func _visual_tile(cell: Vector2i) -> int:
	var tile := run.tile_at(cell)
	match tile:
		Run.FLOOR:
			return 0
		Run.FLOOR_DECO:
			return 1
		Run.GRASS:
			return 2
		Run.HIGH_GRASS:
			return 66
		Run.WATER:
			# DungeonTileSheet.stitchWaterTile uses bits top/right/bottom/left.
			var mask := 0
			var directions := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
			for index in range(4):
				var direction: Vector2i = directions[index]
				var neighbor := run.tile_at(cell + direction)
				if neighbor != Run.WATER and not Run.is_wall_tile(neighbor):
					mask += 1 << index
			return 32 + mask
		Run.CLOSED_DOOR:
			return 56
		Run.OPEN_DOOR:
			return 57
		Run.ENTRANCE:
			return 16
		Run.EXIT:
			return 17
		Run.WALL_DECO:
			return 49
		_:
			return 48


func _draw_sprite(texture: Texture2D, source: Rect2, cell: Rect2) -> void:
	draw_texture_rect_region(texture, cell, source)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pointer: Vector2 = event.position
		if pointer.y < MAP_TOP or pointer.y >= MAP_TOP + _board_rows() * CELL_SIZE:
			return
		var cols := _board_cols()
		var left := (size.x - cols * CELL_SIZE) * 0.5
		var x := int((pointer.x - left) / CELL_SIZE)
		var y := int((pointer.y - MAP_TOP) / CELL_SIZE)
		if x < 0 or x >= cols or y < 0 or y >= _board_rows():
			return
		var target: Vector2i = _camera_origin() + Vector2i(x, y)
		if target == run.hero:
			return
		if maxi(absi(target.x - run.hero.x), absi(target.y - run.hero.y)) == 1:
			auto_path.clear()
			run.step(target - run.hero)
			_refresh()
		elif run.is_explored(target):
			auto_path = run.path_to(target)
			auto_elapsed = 0.2


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var direction := Vector2i.ZERO
	match event.keycode:
		KEY_UP, KEY_W, KEY_K:
			direction = Vector2i.UP
		KEY_DOWN, KEY_S, KEY_J:
			direction = Vector2i.DOWN
		KEY_LEFT, KEY_A, KEY_H:
			direction = Vector2i.LEFT
		KEY_RIGHT, KEY_D, KEY_L:
			direction = Vector2i.RIGHT
		KEY_SPACE, KEY_PERIOD:
			_on_wait()
			return
		KEY_P:
			_on_potion()
			return
	if direction != Vector2i.ZERO:
		auto_path.clear()
		run.step(direction)
		_refresh()


func _process(delta: float) -> void:
	if auto_path.is_empty() or run.hp <= 0:
		return
	auto_elapsed += delta
	if auto_elapsed < 0.16:
		return
	auto_elapsed = 0.0
	var next: Vector2i = auto_path.front()
	var before: Vector2i = run.hero
	var before_depth: int = run.depth
	if not run.step(next - before):
		auto_path.clear()
	elif run.hero == before:
		# Opening a door takes a turn; keep the same path step for the next tick.
		if run.tile_at(next) != Run.OPEN_DOOR:
			auto_path.clear()
	elif run.depth != before_depth:
		auto_path.clear()
	else:
		auto_path.pop_front()
	if run.has_visible_enemy():
		auto_path.clear()
	_refresh()


func _on_wait() -> void:
	auto_path.clear()
	run.wait_turn()
	_refresh()


func _on_potion() -> void:
	auto_path.clear()
	run.drink_potion()
	_refresh()


func _on_restart() -> void:
	auto_path.clear()
	run.start()
	autosave_enabled = true
	_refresh()


func _refresh() -> void:
	status_label.text = "%d층  HP %d/%d  물약 %d  턴 %d" % [
		run.depth, run.hp, run.max_hp, run.potion_count, run.turns
	]
	message_label.text = run.message
	potion_button.disabled = run.potion_count == 0 or run.hp >= run.max_hp
	if autosave_enabled:
		var saved: bool = SpdSave.save(run, 1)
		if not saved and not save_failed:
			message_label.text += " 저장에 실패했습니다."
		save_failed = not saved
	queue_redraw()
