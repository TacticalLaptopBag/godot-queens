class_name GameTheme
extends Resource


@export var name: String
@export var default_clear_color: Color
@export var ui_theme: Theme

@export_group("UI")
@export var panel_raised_style: StyleBox
@export var panel_accent_style: StyleBox

@export_group("Tile")
@export var normal: Color
@export var mark: Color
@export var crown: Color
@export var selection: Color
@export var regions: Array[Color] = []
