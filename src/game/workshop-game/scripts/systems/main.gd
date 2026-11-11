extends Node2D

@onready var score_label: Label = %ScoreLabel

func update_score_hud(new_score: int) -> void:
	if score_label:
		score_label.text = "Score: " +str(new_score)
