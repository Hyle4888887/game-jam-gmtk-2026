extends Control
@onready var first_scene = load(res:://) #il faut le path de la scéne du début

#serve a rien mais au cas ou
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

#les signaux des boutons
func _on_start_button_down() -> void:
	#musique ou son d'appui sur le bouton ici
	await  get_tree().create_timer(1).timeout
	get_tree().change_scene_to_packed(first_scene)


func _on_quit_button_down() -> void:
	get_tree().quit()
