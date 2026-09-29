extends RefCounted
class_name GlyphAtlas

const LATIN_TEXTURE: Texture2D = preload("res://assets/user_font_latin.png")
const CYRILLIC_TEXTURE: Texture2D = preload("res://assets/user_font_cyrillic.png")

const LATIN_ROWS := [
	{"text": "ABCDEFGHI", "y": Vector2i(45, 176), "x": [Vector2i(52, 157), Vector2i(203, 295), Vector2i(335, 425), Vector2i(464, 561), Vector2i(604, 692), Vector2i(731, 816), Vector2i(858, 959), Vector2i(996, 1090), Vector2i(1135, 1202)]},
	{"text": "JKLMNOPQR", "y": Vector2i(216, 347), "x": [Vector2i(35, 132), Vector2i(172, 261), Vector2i(300, 384), Vector2i(421, 533), Vector2i(576, 665), Vector2i(706, 806), Vector2i(846, 933), Vector2i(969, 1074), Vector2i(1116, 1220)]},
	{"text": "STUVWXYZ", "y": Vector2i(379, 505), "x": [Vector2i(99, 189), Vector2i(224, 333), Vector2i(364, 454), Vector2i(493, 584), Vector2i(619, 749), Vector2i(782, 878), Vector2i(917, 1014), Vector2i(1047, 1150)]},
	{"text": "abcdefghi", "y": Vector2i(540, 681), "x": [Vector2i(66, 151), Vector2i(206, 284), Vector2i(334, 405), Vector2i(452, 528), Vector2i(591, 668), Vector2i(721, 800), Vector2i(848, 925), Vector2i(995, 1066), Vector2i(1146, 1170)]},
	{"text": "jklmnopqr", "y": Vector2i(694, 837), "x": [Vector2i(55, 126), Vector2i(199, 277), Vector2i(338, 362), Vector2i(433, 536), Vector2i(588, 668), Vector2i(723, 803), Vector2i(860, 934), Vector2i(991, 1069), Vector2i(1130, 1202)]},
	{"text": "stuvwxyz", "y": Vector2i(846, 985), "x": [Vector2i(87, 162), Vector2i(211, 291), Vector2i(349, 440), Vector2i(489, 578), Vector2i(622, 747), Vector2i(794, 884), Vector2i(955, 1027), Vector2i(1089, 1186)]},
	{"text": "0123456789", "y": Vector2i(1002, 1121), "x": [Vector2i(49, 127), Vector2i(171, 232), Vector2i(269, 364), Vector2i(398, 485), Vector2i(518, 604), Vector2i(638, 721), Vector2i(760, 847), Vector2i(876, 965), Vector2i(997, 1084), Vector2i(1122, 1202)]},
	{"text": ".,;:!?+-/\\()[]_*", "y": Vector2i(1140, 1230), "x": [Vector2i(59, 80), Vector2i(129, 154), Vector2i(191, 208), Vector2i(251, 275), Vector2i(310, 327), Vector2i(360, 409), Vector2i(439, 493), Vector2i(521, 572), Vector2i(593, 638), Vector2i(664, 717), Vector2i(757, 788), Vector2i(823, 854), Vector2i(907, 942), Vector2i(977, 1012), Vector2i(1051, 1113), Vector2i(1142, 1207)]},
]

const CYRILLIC_UPPER_ROWS := [
	{"text": "АБВГҐДЕЄЖЗ", "y": Vector2i(38, 172), "x": [Vector2i(41, 143), Vector2i(175, 261), Vector2i(283, 375), Vector2i(403, 476), Vector2i(503, 578), Vector2i(590, 705), Vector2i(732, 817), Vector2i(843, 932), Vector2i(960, 1084), Vector2i(1111, 1200)]},
	{"text": "ИІЇЙКЛМНОП", "y": Vector2i(174, 309), "x": [Vector2i(40, 131), Vector2i(171, 234), Vector2i(281, 337), Vector2i(379, 466), Vector2i(499, 588), Vector2i(611, 710), Vector2i(733, 844), Vector2i(869, 970), Vector2i(996, 1094), Vector2i(1123, 1215)]},
	{"text": "РСТУФХЦЧШЩ", "y": Vector2i(328, 457), "x": [Vector2i(44, 130), Vector2i(157, 253), Vector2i(274, 366), Vector2i(389, 487), Vector2i(502, 609), Vector2i(626, 726), Vector2i(753, 854), Vector2i(870, 942), Vector2i(975, 1090), Vector2i(1112, 1221)]},
	{"text": "ЬЮЯ", "y": Vector2i(460, 578), "x": [Vector2i(423, 511), Vector2i(541, 677), Vector2i(706, 805)]},
]

const CYRILLIC_LOWER_ROWS := [
	{"text": "абвгґдеєжз", "y": Vector2i(582, 727)},
	{"text": "иіїйклмноп", "y": Vector2i(730, 842)},
	{"text": "рстуфхцчшщ", "y": Vector2i(844, 963)},
	{"text": "ьюя", "y": Vector2i(963, 1058), "x": [Vector2i(400, 526), Vector2i(535, 696), Vector2i(696, 840)]},
]

const CYRILLIC_CELLS := [
	Vector2i(25, 145), Vector2i(145, 267), Vector2i(267, 382), Vector2i(382, 495), Vector2i(495, 607),
	Vector2i(607, 733), Vector2i(733, 861), Vector2i(861, 972), Vector2i(972, 1097), Vector2i(1097, 1230),
]

static var _glyphs: Dictionary = {}

static func glyph(character: String) -> Dictionary:
	if _glyphs.is_empty():
		_build()
	if not _glyphs.has(character):
		return {}
	return _glyphs[character].duplicate()

static func _build() -> void:
	_glyphs.clear()
	var latin_image := LATIN_TEXTURE.get_image()
	for row in LATIN_ROWS:
		_store_intervals(LATIN_TEXTURE, latin_image, row["text"], row["y"], row["x"])
	var cyrillic_image := CYRILLIC_TEXTURE.get_image()
	for row in CYRILLIC_UPPER_ROWS:
		_store_intervals(CYRILLIC_TEXTURE, cyrillic_image, row["text"], row["y"], row["x"])
	for row in CYRILLIC_LOWER_ROWS:
		if row.has("x"):
			_store_intervals(CYRILLIC_TEXTURE, cyrillic_image, row["text"], row["y"], row["x"])
		else:
			_store_cells(CYRILLIC_TEXTURE, cyrillic_image, row["text"], row["y"])

static func _store_intervals(texture: Texture2D, image: Image, characters: String, y_band: Vector2i, intervals: Array) -> void:
	for index in range(mini(characters.length(), intervals.size())):
		var interval: Vector2i = intervals[index]
		_store_glyph(texture, image, characters.substr(index, 1), Rect2i(interval.x, y_band.x, interval.y - interval.x, y_band.y - y_band.x))

static func _store_cells(texture: Texture2D, image: Image, characters: String, y_band: Vector2i) -> void:
	for index in range(mini(characters.length(), CYRILLIC_CELLS.size())):
		var cell: Vector2i = CYRILLIC_CELLS[index]
		_store_glyph(texture, image, characters.substr(index, 1), Rect2i(cell.x, y_band.x, cell.y - cell.x, y_band.y - y_band.x))

static func _store_glyph(texture: Texture2D, image: Image, character: String, bounds: Rect2i) -> void:
	var left := bounds.position.x
	var right := bounds.end.x
	var top := bounds.position.y
	var bottom := bounds.end.y
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.08 and pixel.b > 0.05:
				left = mini(left, x)
				right = maxi(right, x + 1)
				top = mini(top, y)
				bottom = maxi(bottom, y + 1)
	if right > left and bottom > top:
		_glyphs[character] = {"texture": texture, "region": Rect2(left - 1, top - 1, right - left + 2, bottom - top + 2)}
