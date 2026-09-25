extends SceneTree

const MAIN = preload("res://main.gd")
const FONT = preload("res://assets/fonts/Galmuri11.ttf")


func _initialize() -> void:
	for index in range("한글 층 쥐 뱀 회복 물약 새 게임".length()):
		var codepoint := "한글 층 쥐 뱀 회복 물약 새 게임".unicode_at(index)
		if codepoint != 32 and not FONT.has_char(codepoint):
			push_error("Korean UI font is missing U+%04X" % codepoint)
			quit(1)
			return
	var screen: Control = MAIN.new()
	root.add_child(screen)
	call_deferred("_check_font", screen)


func _check_font(screen: Control) -> void:
	if screen.status_label.get_theme_font("font") != FONT \
			or screen.message_label.get_theme_font("font") != FONT \
			or screen.wait_button.get_theme_font("font") != FONT:
		push_error("Korean font was not applied to all UI controls")
		quit(1)
		return
	print("Korean UI font passed")
	quit()
