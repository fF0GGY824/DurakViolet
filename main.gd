
extends Control

const SUITS = ["♠", "♥", "♦", "♣"]
const RANKS = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "В", "Д", "К", "Т"]
const HAND_SIZE = 6

const WHITE = Color("#F8F1FF")
const PURPLE = Color("#933EFF")
const DARK = Color("#12071F")

var deck: Array = []
var player_hand: Array = []
var bot_hand: Array = []
var table_cards: Array = []
var discard_pile: Array = []

# 0 — атакует игрок, 1 — компьютер.
var attacker: int = 0
var selected_index: int = -1
var first_bout: bool = true
var game_finished: bool = false
var bot_busy: bool = false
var bot_wants_take: bool = false
var replacement_mode: bool = false

var trump_mode: String = "suit"
var trump_suit: String = ""
var message: String = ""

var bot_label: Label
var deck_label: Label
var info_label: Label
var table_box: GridContainer
var hand_box: HBoxContainer
var action_box: GridContainer

var joker_dialog: ConfirmationDialog
var joker_options_box: VBoxContainer
var joker_action: String = ""
var joker_selected_index: int = -1
var joker_replace_pair: int = -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	build_ui()
	new_game()


# ==========================================
# ИНТЕРФЕЙС
# ==========================================

func make_style(
	bg_color: Color,
	border_color: Color,
	corner_radius: int = 12
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func make_label(
	label_text: String,
	font_size: int,
	font_color: Color = WHITE
) -> Label:
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	return label


func build_ui() -> void:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if ResourceLoader.exists("res://background.png"):
		background.texture = load("res://background.png")
	else:
		var fallback := ColorRect.new()
		fallback.color = DARK
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fallback)

	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 7)
	margin.add_child(root)

	root.add_child(make_label("♠ ДУРАК VIOLET ♠", 23, Color("#D6A7FF")))

	var bot_panel := PanelContainer.new()
	bot_panel.add_theme_stylebox_override(
		"panel",
		make_style(Color(0.08, 0.02, 0.15, 0.88), PURPLE, 15)
	)
	root.add_child(bot_panel)

	var bot_content := VBoxContainer.new()
	bot_panel.add_child(bot_content)
	bot_content.add_child(make_label("КОМПЬЮТЕР", 18))

	bot_label = make_label("", 15)
	bot_content.add_child(bot_label)

	var table_panel := PanelContainer.new()
	table_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_panel.add_theme_stylebox_override(
		"panel",
		make_style(Color(0.07, 0.02, 0.13, 0.67), Color("#6227A4"), 17)
	)
	root.add_child(table_panel)

	var table_content := VBoxContainer.new()
	table_panel.add_child(table_content)

	deck_label = make_label("", 13)
	table_content.add_child(deck_label)

	var table_scroll := ScrollContainer.new()
	table_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_content.add_child(table_scroll)

	table_box = GridContainer.new()
	table_box.columns = 3
	table_box.add_theme_constant_override("h_separation", 5)
	table_box.add_theme_constant_override("v_separation", 6)
	table_scroll.add_child(table_box)

	info_label = make_label("", 13)
	info_label.custom_minimum_size = Vector2(0, 45)
	root.add_child(info_label)

	root.add_child(make_label("ТВОИ КАРТЫ", 17, Color("#D8A8FF")))

	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(0, 108)
	root.add_child(hand_scroll)

	hand_box = HBoxContainer.new()
	hand_box.add_theme_constant_override("separation", -8)
	hand_scroll.add_child(hand_box)

	action_box = GridContainer.new()
	action_box.columns = 3
	action_box.add_theme_constant_override("h_separation", 5)
	action_box.add_theme_constant_override("v_separation", 5)
	root.add_child(action_box)

	add_action_button("Сыграть", play_selected)
	add_action_button("Подкинуть", throw_selected)
	add_action_button("Перевести", transfer_selected)
	add_action_button("Добрать", draw_cards)
	add_action_button("Бито!", finish_bout)
	add_action_button("Забрать", take_cards)
	add_action_button("Новая игра", new_game)

	build_joker_dialog()


func add_action_button(button_text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(94, 43)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	button.add_theme_stylebox_override(
		"normal",
		make_style(Color("#48216F"), PURPLE)
	)
	button.add_theme_stylebox_override(
		"hover",
		make_style(Color("#7134A8"), Color("#D5A6FF"))
	)
	button.add_theme_stylebox_override(
		"pressed",
		make_style(Color("#2B1147"), PURPLE)
	)

	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(callback)
	action_box.add_child(button)


func make_card_button(
	card: Dictionary,
	is_selected: bool = false
) -> Button:
	var button := Button.new()
	button.text = card_name(card)
	button.custom_minimum_size = Vector2(76, 90)

	var bg_color := Color("#F7F2FF")
	var border_color := Color("#9956DC")

	if is_selected:
		bg_color = Color("#DDBBFF")
		border_color = Color.WHITE

	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(
			state,
			make_style(bg_color, border_color, 9)
		)

	var font_color := Color("#241134")
	var suit := effective_suit(card)

	if suit == "♥" or suit == "♦":
		font_color = Color("#C82D50")

	if is_mark(card):
		font_color = Color("#862FD0")

	if is_joker(card):
		if card["joker_color"] == "red":
			font_color = Color("#D22B52")
		else:
			font_color = Color("#261234")

	for state in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_disabled_color"
	]:
		button.add_theme_color_override(state, font_color)

	button.add_theme_font_size_override("font_size", 15)
	return button


func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


# ==========================================
# КОЛОДА И НАЧАЛО ИГРЫ
# ==========================================

func new_game() -> void:
	deck.clear()
	player_hand.clear()
	bot_hand.clear()
	table_cards.clear()
	discard_pile.clear()

	attacker = 0
	selected_index = -1
	first_bout = true
	game_finished = false
	bot_busy = false
	bot_wants_take = false
	replacement_mode = false
	joker_selected_index = -1
	joker_replace_pair = -1

	if joker_dialog != null:
		joker_dialog.hide()

	for suit in SUITS:
		for rank in range(2, 15):
			deck.append({
				"rank": rank,
				"suit": suit,
				"special": "",
				"joker_color": "",
				"copy_rank": -1,
				"copy_suit": ""
			})

	deck.append({
		"rank": 20,
		"suit": "★",
		"special": "joker",
		"joker_color": "red",
		"copy_rank": -1,
		"copy_suit": ""
	})

	deck.append({
		"rank": 21,
		"suit": "★",
		"special": "joker",
		"joker_color": "black",
		"copy_rank": -1,
		"copy_suit": ""
	})

	deck.append({
		"rank": 22,
		"suit": "✦",
		"special": "mark",
		"joker_color": "",
		"copy_rank": -1,
		"copy_suit": ""
	})

	deck.shuffle()

	# Первая карта задаёт козырь и остаётся в колоде.
	setup_trump(deck[0])

	draw_to_six(player_hand)
	draw_to_six(bot_hand)

	message = "Твой ход! Выбери карту."
	update_ui()


func setup_trump(card: Dictionary) -> void:
	if is_joker(card):
		if card["joker_color"] == "red":
			trump_mode = "red"
			trump_suit = "♥ ♦"
		else:
			trump_mode = "black"
			trump_suit = "♠ ♣"
	elif is_mark(card):
		trump_mode = "none"
		trump_suit = "НЕТ"
	else:
		trump_mode = "suit"
		trump_suit = str(card["suit"])


func draw_to_six(hand: Array) -> void:
	while hand.size() < HAND_SIZE and not deck.is_empty():
		hand.append(deck.pop_back())


# ==========================================
# ПРАВИЛА КАРТ
# ==========================================

func is_joker(card: Dictionary) -> bool:
	return card.get("special", "") == "joker"


func is_mark(card: Dictionary) -> bool:
	return card.get("special", "") == "mark"


func effective_rank(card: Dictionary) -> int:
	if is_joker(card):
		return int(card.get("copy_rank", -1))
	if is_mark(card):
		return 100
	return int(card["rank"])


func effective_suit(card: Dictionary) -> String:
	if is_joker(card):
		return str(card.get("copy_suit", ""))
	if is_mark(card):
		return ""
	return str(card["suit"])


func rank_name(rank: int) -> String:
	if rank < 2 or rank > 14:
		return "?"
	return RANKS[rank - 2]


func card_name(card: Dictionary) -> String:
	if is_mark(card):
		return "МЕТКА"

	if is_joker(card):
		var icon := "🔴"
		if card["joker_color"] == "black":
			icon = "⚫"

		if effective_rank(card) == 100:
			return icon + "→МЕТКА"

		if effective_rank(card) != -1:
			return (
				icon + "→"
				+ rank_name(effective_rank(card))
				+ effective_suit(card)
			)

		return icon + " ДЖОКЕР"

	return rank_name(int(card["rank"])) + str(card["suit"])


func is_trump(card: Dictionary) -> bool:
	var suit := effective_suit(card)

	if trump_mode == "none":
		return false
	if trump_mode == "red":
		return suit == "♥" or suit == "♦"
	if trump_mode == "black":
		return suit == "♠" or suit == "♣"

	return suit == trump_suit


func can_start_attack(card: Dictionary) -> bool:
	return not is_joker(card) and not is_mark(card)


func joker_can_copy(card: Dictionary) -> bool:
	if effective_rank(card) == 100:
		return true

	return (
		effective_rank(card) >= 2
		and effective_suit(card) != ""
	)


func make_joker_copy(
	joker: Dictionary,
	target: Dictionary
) -> Dictionary:
	var result: Dictionary = joker.duplicate(true)

	if effective_rank(target) == 100:
		result["copy_rank"] = 100
		result["copy_suit"] = ""
	else:
		result["copy_rank"] = effective_rank(target)
		result["copy_suit"] = effective_suit(target)

	return result


func reset_joker(card: Dictionary) -> Dictionary:
	if not is_joker(card):
		return card

	var result: Dictionary = card.duplicate(true)
	result["copy_rank"] = -1
	result["copy_suit"] = ""
	return result


func can_beat(card: Dictionary, target: Dictionary) -> bool:
	# Настоящая метка отбивает любую карту.
	if is_mark(card):
		return true

	# Джокер, скопировавший метку со стола.
	if is_joker(card) and effective_rank(card) == 100:
		return true

	# Метку обычной картой отбить нельзя.
	if effective_rank(target) == 100:
		return false

	# Джокер может отбить только ТОТ ЖЕ козырь.
	# Обычную карту джокер не отбивает.
	if is_joker(card):
		return (
			is_trump(target)
			and effective_rank(card) == effective_rank(target)
			and effective_suit(card) == effective_suit(target)
		)

	# Обычная карта старше той же масти.
	if effective_suit(card) == effective_suit(target):
		return effective_rank(card) > effective_rank(target)

	# Козырь отбивает некозырную карту.
	if is_trump(card) and not is_trump(target):
		return true

	return false


func current_limit() -> int:
	if first_bout:
		return 8
	return 10


func first_unbeaten_pair() -> int:
	for i in range(table_cards.size()):
		if table_cards[i]["defense"].is_empty():
			return i
	return -1


func table_has_rank(rank: int) -> bool:
	for pair in table_cards:
		if effective_rank(pair["attack"]) == rank:
			return true

		if not pair["defense"].is_empty():
			if effective_rank(pair["defense"]) == rank:
				return true

	return false


# ==========================================
# ВЫБОР КАРТЫ ДЛЯ ДЖОКЕРА
# ==========================================

func build_joker_dialog() -> void:
	joker_dialog = ConfirmationDialog.new()
	joker_dialog.title = "ДЖОКЕР — ВЫБЕРИ КАРТУ"
	joker_dialog.ok_button_text = "Закрыть"
	add_child(joker_dialog)

	# Godot 4: get_vbox() здесь не используется.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(290, 230)
	joker_dialog.add_child(scroll)

	joker_options_box = VBoxContainer.new()
	joker_options_box.add_theme_constant_override("separation", 6)
	scroll.add_child(joker_options_box)


func show_joker_choice(
	action: String,
	replace_pair: int = -1
) -> void:
	if selected_index < 0 or selected_index >= player_hand.size():
		return

	joker_action = action
	joker_selected_index = selected_index
	joker_replace_pair = replace_pair

	clear_children(joker_options_box)

	var available := 0

	# Копировать можно только карты со стола.
	for pair in table_cards:
		var options: Array = [pair["attack"]]

		if not pair["defense"].is_empty():
			options.append(pair["defense"])

		for target in options:
			if not joker_can_copy(target):
				continue

			var joker: Dictionary = player_hand[joker_selected_index]
			var copied := make_joker_copy(joker, target)

			if action == "defend":
				var pair_index := first_unbeaten_pair()

				if pair_index == -1:
					continue

				if not can_beat(
					copied,
					table_cards[pair_index]["attack"]
				):
					continue

			if action == "replace":
				if replace_pair < 0 or replace_pair >= table_cards.size():
					continue

				if not can_beat(
					copied,
					table_cards[replace_pair]["attack"]
				):
					continue

			if action == "throw" or action == "transfer":
				if not table_has_rank(effective_rank(copied)):
					continue

				# Джокер-копия метки не используется
				# для подкидывания или перевода.
				if effective_rank(copied) == 100:
					continue

			var button := Button.new()
			button.text = "Копировать " + card_name(target)
			button.custom_minimum_size = Vector2(250, 43)
			button.pressed.connect(
				choose_joker_target.bind(target.duplicate(true))
			)
			joker_options_box.add_child(button)
			available += 1

	if available == 0:
		message = "Нет подходящей карты на столе."
		update_ui()
		return

	joker_dialog.popup_centered(Vector2i(330, 320))


func choose_joker_target(target: Dictionary) -> void:
	joker_dialog.hide()

	if game_finished or bot_busy:
		return

	if joker_selected_index < 0:
		return
	if joker_selected_index >= player_hand.size():
		return

	var joker: Dictionary = player_hand[joker_selected_index]

	if not is_joker(joker):
		return

	var found := false

	for pair in table_cards:
		if pair["attack"] == target:
			found = true
			break

		if not pair["defense"].is_empty():
			if pair["defense"] == target:
				found = true
				break

	if not found:
		message = "Этой карты больше нет на столе."
		update_ui()
		return

	var copied := make_joker_copy(joker, target)
	var hand_index := joker_selected_index
	var action := joker_action
	var pair_index := joker_replace_pair

	joker_selected_index = -1
	joker_replace_pair = -1

	match action:
		"defend":
			execute_defense(hand_index, copied)
		"throw":
			execute_throw(hand_index, copied)
		"transfer":
			execute_transfer(hand_index, copied)
		"replace":
			execute_replacement(pair_index, hand_index, copied)


# ==========================================
# АТАКА И ЗАЩИТА
# ==========================================

func play_selected() -> void:
	if game_finished or bot_busy:
		return

	if selected_index < 0 or selected_index >= player_hand.size():
		message = "Выбери карту."
		update_ui()
		return

	var card: Dictionary = player_hand[selected_index]

	if table_cards.is_empty():
		if attacker != 0:
			message = "Сейчас ход компьютера."
			update_ui()
			return

		if not can_start_attack(card):
			message = "Джокер и метка не начинают атаку."
			update_ui()
			return

		player_hand.remove_at(selected_index)
		table_cards.append({
			"attack": card,
			"defense": {}
		})

		selected_index = -1
		message = "Компьютер отбивается..."
		update_ui()
		bot_defend()
		return

	if attacker == 1:
		if first_unbeaten_pair() == -1:
			message = "Все карты отбиты. Нажми «Бито!»."
			update_ui()
			return

		if is_joker(card):
			show_joker_choice("defend")
		else:
			execute_defense(selected_index, card)
		return

	message = "Используй кнопку «Подкинуть»."
	update_ui()


func execute_defense(hand_index: int, card: Dictionary) -> void:
	if attacker != 1 or bot_busy:
		return
	if hand_index < 0 or hand_index >= player_hand.size():
		return

	var pair_index := first_unbeaten_pair()
	if pair_index == -1:
		return

	var attack_card: Dictionary = table_cards[pair_index]["attack"]

	if not can_beat(card, attack_card):
		message = "Эта карта не отбивает."
		update_ui()
		return

	player_hand.remove_at(hand_index)
	table_cards[pair_index]["defense"] = card

	selected_index = -1
	message = "Отбито! Можно добрать или нажать «Бито!»."
	update_ui()


# ==========================================
# ЗАМЕНА КАРТЫ ПОСЛЕ ДОБОРА
# ==========================================

func replace_defense(pair_index: int) -> void:
	if game_finished or bot_busy or not replacement_mode:
		return
	if attacker != 1:
		return
	if pair_index < 0 or pair_index >= table_cards.size():
		return

	if selected_index < 0 or selected_index >= player_hand.size():
		message = "Выбери новую карту из руки."
		update_ui()
		return

	var new_card: Dictionary = player_hand[selected_index]

	if is_joker(new_card):
		show_joker_choice("replace", pair_index)
	else:
		execute_replacement(pair_index, selected_index, new_card)


func execute_replacement(
	pair_index: int,
	hand_index: int,
	new_card: Dictionary
) -> void:
	if not replacement_mode or attacker != 1:
		return
	if pair_index < 0 or pair_index >= table_cards.size():
		return
	if hand_index < 0 or hand_index >= player_hand.size():
		return

	var pair: Dictionary = table_cards[pair_index]

	if pair["defense"].is_empty():
		return

	if not can_beat(new_card, pair["attack"]):
		message = "Новая карта не подходит."
		update_ui()
		return

	var old_card: Dictionary = pair["defense"]

	table_cards[pair_index]["defense"] = new_card
	player_hand[hand_index] = reset_joker(old_card)

	selected_index = -1
	message = "Карта заменена!"
	update_ui()


# ==========================================
# ПОДКИДЫВАНИЕ
# ==========================================

func throw_selected() -> void:
	if game_finished or bot_busy:
		return

	if attacker != 0 or table_cards.is_empty():
		message = "Сейчас нельзя подкинуть."
		update_ui()
		return

	if selected_index < 0 or selected_index >= player_hand.size():
		message = "Выбери карту."
		update_ui()
		return

	if not bot_wants_take and first_unbeaten_pair() != -1:
		message = "Компьютер ещё отбивается."
		update_ui()
		return

	if table_cards.size() >= current_limit():
		message = "Лимит карт на столе."
		update_ui()
		return

	var card: Dictionary = player_hand[selected_index]

	if is_joker(card):
		show_joker_choice("throw")
	else:
		execute_throw(selected_index, card)


func execute_throw(hand_index: int, card: Dictionary) -> void:
	if game_finished or bot_busy:
		return
	if attacker != 0 or table_cards.is_empty():
		return
	if hand_index < 0 or hand_index >= player_hand.size():
		return
	if not bot_wants_take and first_unbeaten_pair() != -1:
		return
	if table_cards.size() >= current_limit():
		return

	if is_mark(card) or effective_rank(card) == 100:
		message = "Метка не подкидывается."
		update_ui()
		return

	if not table_has_rank(effective_rank(card)):
		message = "Такого достоинства нет на столе."
		update_ui()
		return

	player_hand.remove_at(hand_index)
	table_cards.append({
		"attack": card,
		"defense": {}
	})

	selected_index = -1

	if bot_wants_take:
		message = "Подкинуто! Компьютер ждёт «Бито!»."
		update_ui()
	else:
		message = "Компьютер отбивается..."
		update_ui()
		bot_defend()


# ==========================================
# ПЕРЕВОД
# ==========================================

func transfer_selected() -> void:
	if game_finished or bot_busy:
		return

	if attacker != 1 or table_cards.is_empty():
		message = "Сейчас нельзя переводить."
		update_ui()
		return

	if selected_index < 0 or selected_index >= player_hand.size():
		message = "Выбери карту."
		update_ui()
		return

	var card: Dictionary = player_hand[selected_index]

	if is_joker(card):
		show_joker_choice("transfer")
	else:
		execute_transfer(selected_index, card)


func execute_transfer(hand_index: int, card: Dictionary) -> void:
	if attacker != 1 or bot_busy:
		return
	if table_cards.is_empty():
		return
	if hand_index < 0 or hand_index >= player_hand.size():
		return
	if table_cards.size() >= current_limit():
		return
	if first_unbeaten_pair() == -1:
		return

	if is_mark(card) or effective_rank(card) == 100:
		message = "Метка не переводит."
		update_ui()
		return

	if not table_has_rank(effective_rank(card)):
		message = "Не подходит для перевода."
		update_ui()
		return

	if bot_hand.size() < table_cards.size() + 1:
		message = "Компьютеру не хватает карт."
		update_ui()
		return

	player_hand.remove_at(hand_index)
	table_cards.append({
		"attack": card,
		"defense": {}
	})

	attacker = 0
	selected_index = -1
	replacement_mode = false

	message = "Перевод! Компьютер отбивается."
	update_ui()
	bot_defend()


# ==========================================
# ДОБОР
# ==========================================

func draw_cards() -> void:
	if game_finished or bot_busy:
		return

	if deck.is_empty():
		message = "Колода закончилась."
		update_ui()
		return

	if player_hand.size() >= HAND_SIZE:
		message = "У тебя уже 6 карт."
		update_ui()
		return

	var before := player_hand.size()
	draw_to_six(player_hand)
	var drawn := player_hand.size() - before

	if (
		drawn > 0
		and attacker == 1
		and not table_cards.is_empty()
		and first_unbeaten_pair() == -1
	):
		replacement_mode = true
		message = "Выбери карту из руки, затем нажми на свою защиту."
	else:
		message = "Добрано карт: %d." % drawn

	update_ui()


# ==========================================
# ИГРОК ЗАБИРАЕТ
# ==========================================

func take_cards() -> void:
	if game_finished or bot_busy:
		return

	if attacker != 1 or table_cards.is_empty():
		message = "Сейчас нельзя забрать."
		update_ui()
		return

	for pair in table_cards:
		player_hand.append(reset_joker(pair["attack"]))

		if not pair["defense"].is_empty():
			player_hand.append(reset_joker(pair["defense"]))

	table_cards.clear()

	draw_to_six(player_hand)
	draw_to_six(bot_hand)

	first_bout = false
	selected_index = -1
	attacker = 1
	bot_wants_take = false
	replacement_mode = false

	check_winner()

	if game_finished:
		update_ui()
		return

	message = "Ты забрал карты. Компьютер ходит."
	update_ui()
	bot_attack()


# ==========================================
# КОМПЬЮТЕР ОТБИВАЕТСЯ
# ==========================================

func bot_defend() -> void:
	if game_finished or bot_busy:
		return

	if bot_wants_take:
		message = "Подкидывай или нажми «Бито!»."
		update_ui()
		return

	bot_busy = true

	while true:
		var pair_index := first_unbeaten_pair()

		if pair_index == -1:
			break

		var attack_card: Dictionary = table_cards[pair_index]["attack"]
		var choice := -1
		var chosen_card: Dictionary = {}

		for i in range(bot_hand.size()):
			var candidate: Dictionary = bot_hand[i]
			var test_card: Dictionary = candidate

			if is_joker(candidate):
				var found := false

				for pair in table_cards:
					var options: Array = [pair["attack"]]

					if not pair["defense"].is_empty():
						options.append(pair["defense"])

					for target in options:
						if not joker_can_copy(target):
							continue

						var copied := make_joker_copy(candidate, target)

						if can_beat(copied, attack_card):
							test_card = copied
							found = true
							break

					if found:
						break

				if not found:
					continue

			if can_beat(test_card, attack_card):
				if choice == -1:
					choice = i
					chosen_card = test_card
				elif effective_rank(test_card) < effective_rank(chosen_card):
					choice = i
					chosen_card = test_card

		if choice == -1:
			if bot_hand.size() < HAND_SIZE and not deck.is_empty():
				draw_to_six(bot_hand)
				continue

			bot_wants_take = true
			bot_busy = false
			message = "Компьютер забирает! Подкидывай или жми «Бито!»."
			update_ui()
			return

		bot_hand.remove_at(choice)
		table_cards[pair_index]["defense"] = chosen_card

	bot_busy = false
	message = "Компьютер отбился. Подкинь или нажми «Бито!»."
	update_ui()


# ==========================================
# КОМПЬЮТЕР АТАКУЕТ
# ==========================================

func bot_attack() -> void:
	if game_finished or bot_busy:
		return

	draw_to_six(bot_hand)

	if bot_hand.is_empty():
		check_winner()
		update_ui()
		return

	var choice := -1

	for i in range(bot_hand.size()):
		if can_start_attack(bot_hand[i]):
			if choice == -1:
				choice = i
			elif effective_rank(bot_hand[i]) < effective_rank(bot_hand[choice]):
				choice = i

	if choice == -1:
		attacker = 0
		message = "Компьютер пропускает ход. Твой ход."
		update_ui()
		return

	var card: Dictionary = bot_hand[choice]
	bot_hand.remove_at(choice)

	table_cards.append({
		"attack": card,
		"defense": {}
	})

	attacker = 1
	selected_index = -1
	bot_wants_take = false
	replacement_mode = false

	message = "Компьютер атакует: " + card_name(card)
	update_ui()


# ==========================================
# БИТО
# ==========================================

func finish_bout() -> void:
	if game_finished or bot_busy:
		return

	if table_cards.is_empty():
		message = "Стол пуст."
		update_ui()
		return

	# Бот забирает только после нажатия «Бито!».
	if bot_wants_take:
		for pair in table_cards:
			bot_hand.append(reset_joker(pair["attack"]))

			if not pair["defense"].is_empty():
				bot_hand.append(reset_joker(pair["defense"]))

		table_cards.clear()
		bot_wants_take = false
		replacement_mode = false
		first_bout = false
		selected_index = -1
		attacker = 0

		draw_to_six(player_hand)
		draw_to_six(bot_hand)

		check_winner()

		if game_finished:
			update_ui()
			return

		message = "Компьютер забрал карты. Твой ход!"
		update_ui()
		return

	if first_unbeaten_pair() != -1:
		message = "Не все карты отбиты."
		update_ui()
		return

	for pair in table_cards:
		discard_pile.append(pair["attack"])

		if not pair["defense"].is_empty():
			discard_pile.append(pair["defense"])

	table_cards.clear()
	replacement_mode = false

	if attacker == 0:
		draw_to_six(player_hand)
		draw_to_six(bot_hand)
	else:
		draw_to_six(bot_hand)
		draw_to_six(player_hand)

	first_bout = false
	selected_index = -1

	check_winner()

	if game_finished:
		update_ui()
		return

	if attacker == 0:
		attacker = 1
		message = "Бито! Компьютер атакует."
		update_ui()
		bot_attack()
	else:
		attacker = 0
		message = "Бито! Твой ход."
		update_ui()


# ==========================================
# ПОБЕДА
# ==========================================

func check_winner() -> void:
	if not deck.is_empty():
		return

	if not table_cards.is_empty():
		return

	if player_hand.is_empty() and bot_hand.is_empty():
		game_finished = true
		message = "НИЧЬЯ!"
	elif player_hand.is_empty():
		game_finished = true
		message = "ТЫ ПОБЕДИЛ!"
	elif bot_hand.is_empty():
		game_finished = true
		message = "КОМПЬЮТЕР ПОБЕДИЛ!"


# ==========================================
# ОБНОВЛЕНИЕ ЭКРАНА
# ==========================================

func update_ui() -> void:
	if not is_node_ready():
		return

	bot_label.text = "Карт у компьютера: %d" % bot_hand.size()

	deck_label.text = (
		"КОЛОДА: %d | КОЗЫРЬ: %s | ЛИМИТ: %d"
		% [deck.size(), trump_suit, current_limit()]
	)

	info_label.text = message

	clear_children(table_box)

	if table_cards.is_empty():
		table_box.add_child(make_label("СТОЛ ПУСТ", 18))

	for i in range(table_cards.size()):
		var pair: Dictionary = table_cards[i]
		var pair_box := VBoxContainer.new()
		pair_box.add_theme_constant_override("separation", 3)

		var attack_button := make_card_button(pair["attack"])
		attack_button.disabled = true
		pair_box.add_child(attack_button)

		if pair["defense"].is_empty():
			pair_box.add_child(make_label("↓ ?", 17))
		else:
			var defense_button := make_card_button(pair["defense"])

			if replacement_mode and attacker == 1:
				defense_button.pressed.connect(
					replace_defense.bind(i)
				)
			else:
				defense_button.disabled = true

			pair_box.add_child(defense_button)

		table_box.add_child(pair_box)

	clear_children(hand_box)

	for i in range(player_hand.size()):
		var card: Dictionary = player_hand[i]
		var button := make_card_button(card, i == selected_index)
		button.pressed.connect(select_card.bind(i))
		hand_box.add_child(button)


func select_card(index: int) -> void:
	if game_finished or bot_busy:
		return

	if index < 0 or index >= player_hand.size():
		return

	selected_index = index

	if replacement_mode:
		message = "Теперь нажми на защитную карту на столе."
	else:
		message = "Выбрана: " + card_name(player_hand[index])

	update_ui()
