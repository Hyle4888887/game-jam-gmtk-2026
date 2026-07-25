extends Control
@onready var menu_principal = load("res://menus/menu_principal.tscn") 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_try_again_button_down() -> void:
	#musique ou son d'appui sur le bouton ici
	await  get_tree().create_timer(1).timeout
	get_tree().change_scene_to_packed(menu_principal)


func _on_quit_button_down() -> void:
	get_tree().quit()
