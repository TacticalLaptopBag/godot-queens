extends Button


@export var off_icon: Texture2D

@onready var on_icon := icon
@onready var board: Board = get_tree().get_first_node_in_group("board")


func _ready() -> void:
	pressed.connect(_on_pressed)
	_update_appearance()


func _on_pressed():
	DataPersistence.colorblind = not DataPersistence.colorblind
	DataPersistence.save()
	_update_appearance()


func _update_appearance():
	icon = on_icon if DataPersistence.colorblind else off_icon
	board.update_appearance()
