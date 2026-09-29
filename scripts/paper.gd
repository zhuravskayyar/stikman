extends Node2D

const LevelDesign = preload("res://scripts/level_design.gd")
const PAPER_TEXTURE: Texture2D = preload("res://assets/notebook_grid.png")
const WORLD_SIZE := LevelDesign.WORLD_SIZE
const PAPER_MARGIN := 420.0

func _draw() -> void:
	var paper_rect := Rect2(Vector2.ONE * -PAPER_MARGIN, WORLD_SIZE + Vector2.ONE * PAPER_MARGIN * 2.0)
	draw_texture_rect(PAPER_TEXTURE, paper_rect, true)
