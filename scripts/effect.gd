extends Node2D

const Art = preload("res://scripts/art.gd")

var kind := "impact"
var lifespan := 0.22
var elapsed := 0.0
var size := 0.22
var sprite: Sprite2D

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = Art.effect(kind)
	sprite.scale = Vector2(size, size)
	add_child(sprite)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifespan:
		queue_free()
		return
	sprite.modulate.a = 1.0 - elapsed / lifespan
	sprite.scale = Vector2.ONE * size * (1.0 + elapsed / lifespan * 0.4)
