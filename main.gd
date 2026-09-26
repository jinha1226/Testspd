extends Control

const Run = preload("res://run.gd")
const SpdSave = preload("res://spd_save.gd")
const SpdCampaign = preload("res://spd_campaign.gd")
const TILE_TEXTURE = preload("res://assets/tiles_sewers.png")
const REGION_TILES = [
	TILE_TEXTURE, preload("res://assets/tiles_prison.png"),
	preload("res://assets/tiles_caves.png"), preload("res://assets/tiles_city.png"),
	preload("res://assets/tiles_halls.png")]
const HERO_TEXTURE = preload("res://assets/warrior.png")
const RAT_TEXTURE = preload("res://assets/rat.png")
const SNAKE_TEXTURE = preload("res://assets/snake.png")
const GNOLL_TEXTURE = preload("res://assets/gnoll.png")
const SWARM_TEXTURE = preload("res://assets/swarm.png")
const CRAB_TEXTURE = preload("res://assets/crab.png")
const SLIME_TEXTURE = preload("res://assets/slime.png")
const ITEM_TEXTURE = preload("res://assets/items.png")
const OTHER_MOBS = {
	"goo": preload("res://assets/goo.png"),
	"skeleton": preload("res://assets/skeleton.png"),
	"thief": preload("res://assets/thief.png"),
	"dm100": preload("res://assets/dm100.png"),
	"guard": preload("res://assets/guard.png"),
	"necromancer": preload("res://assets/necromancer.png"),
	"tengu": preload("res://assets/tengu.png"),
	"bat": preload("res://assets/bat.png"),
	"brute": preload("res://assets/brute.png"),
	"shaman": preload("res://assets/shaman.png"),
	"spinner": preload("res://assets/spinner.png"),
	"dm200": preload("res://assets/dm200.png"),
	"dm300": preload("res://assets/dm300.png"),
	"ghoul": preload("res://assets/ghoul.png"),
	"elemental": preload("res://assets/elemental.png"),
	"warlock": preload("res://assets/warlock.png"),
	"monk": preload("res://assets/monk.png"),
	"golem": preload("res://assets/golem.png"),
	"king": preload("res://assets/king.png"),
	"succubus": preload("res://assets/succubus.png"),
	"eye": preload("res://assets/eye.png"),
	"scorpio": preload("res://assets/scorpio.png"),
	"yog": preload("res://assets/yog.png"),
}
const UI_FONT = preload("res://assets/fonts/Galmuri11.ttf")
const CELL_SIZE := 32.0
const MAP_TOP := 100.0
const MAP_BOTTOM_MARGIN := 252.0

var run = Run.new()
var status_label: Label
var message_label: Label
var wait_button: Button
var potion_button: Button
var food_button: Button
var wand_button: Button
var weapon_upgrade_button: Button
var armor_upgrade_button: Button
var restart_button: Button
var slot_button: OptionButton
var auto_path: Array[Vector2i] = []
var auto_elapsed := 0.0
var active_slot := 1
var autosave_enabled := true
var save_failed := false
var wand_targeting := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var ui_theme := Theme.new()
	ui_theme.default_font = UI_FONT
	theme = ui_theme
	if SpdSave.exists(active_slot):
		if not SpdSave.load(run, active_slot):
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
	status_label.add_theme_font_size_override("font_size", 14)
	add_child(status_label)
	message_label = Label.new()
	message_label.add_theme_color_override("font_color", Color(0.75, 0.79, 0.72))
	message_label.add_theme_font_size_override("font_size", 15)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(message_label)
	wait_button = _button("대기", _on_wait)
	potion_button = _button("물약", _on_potion)
	food_button = _button("식량", _on_food)
	wand_button = _button("지팡이", _on_wand)
	weapon_upgrade_button = _button("무기 강화", _on_upgrade_weapon)
	armor_upgrade_button = _button("갑옷 강화", _on_upgrade_armor)
	restart_button = _button("새 게임", _on_restart)
	slot_button = OptionButton.new()
	for slot in range(1, SpdSave.SLOT_COUNT + 1):
		slot_button.add_item("슬롯 %d" % slot, slot)
	slot_button.selected = active_slot - 1
	slot_button.item_selected.connect(_on_slot_selected)
	add_child(slot_button)


func _button(caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(95, 48)
	button.pressed.connect(callback)
	add_child(button)
	return button


func _layout_ui() -> void:
	status_label.position = Vector2(12, 12)
	status_label.size = Vector2(size.x - 24, 42)
	message_label.position = Vector2(12, 55)
	message_label.size = Vector2(size.x - 24, 40)
	var width := (size.x - 30.0) / 2.0
	var controls: Array[Control] = [wait_button, potion_button, food_button,
		wand_button, weapon_upgrade_button, armor_upgrade_button,
		restart_button, slot_button]
	for index in range(controls.size()):
		var button: Control = controls[index]
		button.position = Vector2(10.0 + (index % 2) * (width + 10.0),
			size.y - 236.0 + int(index / 2) * 58.0)
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
	var terrain_texture: Texture2D = REGION_TILES[SpdCampaign.region(run.depth)]
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
			draw_texture_rect_region(terrain_texture, destination, source, tint)
			if run.is_visible(cell):
				if run.potions.has(cell):
					_draw_sprite(ITEM_TEXTURE, Rect2(0, 22 * 16, 16, 16), destination)
				for item in run.items:
					if item["pos"] == cell:
						_draw_sprite(ITEM_TEXTURE, _item_source(item), destination)
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
			var texture: Texture2D = OTHER_MOBS.get(kind, RAT_TEXTURE)
			_draw_sprite(texture, Rect2(0, 0, 16, 16), cell)


func _item_source(item: Dictionary) -> Rect2:
	match item["kind"]:
		"food": return Rect2(5 * 16, 27 * 16, 16, 16)
		"upgrade": return Rect2(0, 19 * 16, 16, 16)
		"strength": return Rect2(1 * 16, 22 * 16, 16, 16)
		"armor": return Rect2(clampi(int(item["tier"]), 0, 4) * 16, 11 * 16, 16, 16)
		"wand": return Rect2(0, 13 * 16, 16, 16)
		"amulet": return Rect2(13 * 16, 3 * 16, 16, 16)
		"weapon":
			var tier := clampi(int(item["tier"]), 1, 5)
			return Rect2((0 if tier % 2 == 1 else 8) * 16,
				(6 + int((tier - 1) / 2)) * 16, 16, 16)
	return Rect2(0, 0, 16, 16)


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
		if wand_targeting:
			wand_targeting = false
			auto_path.clear()
			run.zap(target)
			_refresh()
			return
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
		KEY_F:
			_on_food()
			return
		KEY_Z:
			_on_wand()
			return
		KEY_U:
			_on_upgrade_weapon()
			return
		KEY_O:
			_on_upgrade_armor()
			return
		KEY_ESCAPE:
			wand_targeting = false
			run.message = "대상을 선택하지 않았습니다."
			_refresh()
			return
	if direction != Vector2i.ZERO:
		auto_path.clear()
		wand_targeting = false
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
	wand_targeting = false
	run.wait_turn()
	_refresh()


func _on_potion() -> void:
	auto_path.clear()
	wand_targeting = false
	run.drink_potion()
	_refresh()


func _on_food() -> void:
	auto_path.clear()
	wand_targeting = false
	run.eat_food()
	_refresh()


func _on_wand() -> void:
	auto_path.clear()
	wand_targeting = run.wand_charges > 0 and not run.won and run.hp > 0
	run.message = "마법으로 공격할 적을 선택하세요." if wand_targeting else "지팡이에 충전량이 없습니다."
	_refresh()


func _on_upgrade_weapon() -> void:
	auto_path.clear()
	wand_targeting = false
	run.upgrade_weapon()
	_refresh()


func _on_upgrade_armor() -> void:
	auto_path.clear()
	wand_targeting = false
	run.upgrade_armor()
	_refresh()


func _on_restart() -> void:
	auto_path.clear()
	wand_targeting = false
	run.start()
	autosave_enabled = true
	_refresh()


func _on_slot_selected(index: int) -> void:
	var slot := index + 1
	if slot == active_slot:
		return
	auto_path.clear()
	wand_targeting = false
	var selected_run = Run.new()
	if SpdSave.exists(slot):
		if not SpdSave.load(selected_run, slot):
			slot_button.select(active_slot - 1)
			message_label.text = "슬롯 %d의 저장 파일을 읽지 못했습니다." % slot
			return
	else:
		selected_run.start()
		selected_run.message = "슬롯 %d에서 새 게임을 시작했습니다." % slot
	run = selected_run
	active_slot = slot
	slot_button.select(index)
	autosave_enabled = true
	save_failed = false
	_refresh()


func _refresh() -> void:
	status_label.text = "%d층 %s  HP %d/%d  Lv%d %d/%d\n무기 %d+%d  갑옷 %d+%d  허기 %d  턴 %d" % [
		run.depth, SpdCampaign.region_name(run.depth), run.hp, run.max_hp,
		run.level, run.experience, 5 + run.level * 5, run.weapon_tier,
		run.weapon_level, run.armor_tier, run.armor_level, run.hunger, run.turns]
	message_label.text = run.message
	potion_button.text = "물약 %d" % run.potion_count
	food_button.text = "식량 %d" % run.food_count
	wand_button.text = "지팡이 %d" % run.wand_charges
	weapon_upgrade_button.text = "무기 강화 %d" % run.upgrade_count
	armor_upgrade_button.text = "갑옷 강화 %d" % run.upgrade_count
	potion_button.disabled = run.potion_count == 0 or run.hp >= run.max_hp or run.won
	food_button.disabled = run.food_count == 0 or run.won or run.hp <= 0
	wand_button.disabled = run.wand_charges == 0 or run.won or run.hp <= 0
	weapon_upgrade_button.disabled = run.upgrade_count == 0 or run.won or run.hp <= 0
	armor_upgrade_button.disabled = run.upgrade_count == 0 or run.won or run.hp <= 0
	if autosave_enabled:
		var saved: bool = SpdSave.save(run, active_slot)
		if not saved and not save_failed:
			message_label.text += " 저장에 실패했습니다."
		save_failed = not saved
	queue_redraw()
