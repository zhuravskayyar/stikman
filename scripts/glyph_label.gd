extends Control
class_name GlyphLabel

const FontAtlas = preload("res://scripts/glyph_atlas.gd")

enum Align { LEFT, CENTER, RIGHT }
enum VerticalAlign { TOP, CENTER, BOTTOM }

var text := "":
	set(value):
		text = value
		queue_redraw()
var font_size := 28.0:
	set(value):
		font_size = maxf(1.0, value)
		queue_redraw()
var font_color := Color("29231d"):
	set(value):
		font_color = value
		queue_redraw()
var alignment: Align = Align.LEFT:
	set(value):
		alignment = value
		queue_redraw()
var vertical_alignment: VerticalAlign = VerticalAlign.TOP:
	set(value):
		vertical_alignment = value
		queue_redraw()
var letter_spacing := 0.08

func _ready() -> void:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform vec4 tint_color : source_color = vec4(1.0); void fragment() { vec4 source = texture(TEXTURE, UV); float ink = clamp(source.b * source.a * 2.0, 0.0, 1.0); COLOR = vec4(tint_color.rgb, ink * tint_color.a * COLOR.a); }"
	var tint_material := ShaderMaterial.new()
	tint_material.shader = shader
	material = tint_material

func _draw() -> void:
	var tint_material := material as ShaderMaterial
	if tint_material != null:
		tint_material.set_shader_parameter("tint_color", font_color)
	var lines := text.split("\n", true)
	var text_height := font_size * 0.92
	if lines.size() > 1:
		text_height += float(lines.size() - 1) * font_size * 1.12
	var vertical_offset := 0.0
	if vertical_alignment == VerticalAlign.CENTER:
		vertical_offset = maxf(0.0, (size.y - text_height) * 0.5)
	elif vertical_alignment == VerticalAlign.BOTTOM:
		vertical_offset = maxf(0.0, size.y - text_height)
	for line_index in range(lines.size()):
		var line: String = lines[line_index]
		var width := _line_width(line)
		var x := 0.0
		if alignment == Align.CENTER:
			x = (size.x - width) * 0.5
		elif alignment == Align.RIGHT:
			x = size.x - width
		var top := vertical_offset + float(line_index) * font_size * 1.12
		for character in line:
			if character == " ":
				x += font_size * 0.42 + font_size * letter_spacing
				continue
			var glyph := FontAtlas.glyph(character)
			if glyph.is_empty():
				draw_string(ThemeDB.fallback_font, Vector2(x, top + font_size * 0.84), character, HORIZONTAL_ALIGNMENT_LEFT, -1.0, roundi(font_size), font_color)
				x += ThemeDB.fallback_font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1.0, roundi(font_size)).x + font_size * letter_spacing
				continue
			var source: Rect2 = glyph["region"]
			var texture: Texture2D = glyph["texture"]
			var glyph_height := font_size * 0.92
			var glyph_width := clampf(glyph_height * source.size.x / source.size.y, font_size * 0.3, font_size * 1.16)
			var glyph_top := top + font_size * 0.02
			if glyph.get("flip", false):
				draw_set_transform(Vector2(x + glyph_width, glyph_top), 0.0, Vector2(-1.0, 1.0))
				draw_texture_rect_region(texture, Rect2(0.0, 0.0, glyph_width, glyph_height), source, font_color)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_texture_rect_region(texture, Rect2(x, glyph_top, glyph_width, glyph_height), source, font_color)
			if glyph.get("dots", false):
				var dot_radius := maxf(1.2, font_size * 0.055)
				draw_circle(Vector2(x + glyph_width * 0.34, glyph_top + font_size * 0.02), dot_radius, font_color)
				draw_circle(Vector2(x + glyph_width * 0.70, glyph_top + font_size * 0.02), dot_radius, font_color)
			if glyph.get("bar", false):
				draw_line(Vector2(x + glyph_width * 0.46, glyph_top + font_size * 0.28), Vector2(x + glyph_width * 0.94, glyph_top + font_size * 0.28), font_color, maxf(1.5, font_size * 0.08), true)
			x += glyph_width + font_size * letter_spacing

func _line_width(line: String) -> float:
	var result := 0.0
	for character in line:
		if character == " ":
			result += font_size * (0.42 + letter_spacing)
			continue
		var glyph := FontAtlas.glyph(character)
		if glyph.is_empty():
			result += ThemeDB.fallback_font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1.0, roundi(font_size)).x + font_size * letter_spacing
		else:
			var source: Rect2 = glyph["region"]
			result += clampf(font_size * 0.92 * source.size.x / source.size.y, font_size * 0.3, font_size * 1.16) + font_size * letter_spacing
	return result
