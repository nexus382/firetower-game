extends Control
class_name RadioPanel

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBox/Title
@onready var body_label: Label = $Panel/VBox/Body
@onready var close_button: Button = $Panel/VBox/CloseButton

func _ready():
    visible = false
    set_process_unhandled_input(true)
    if close_button:
        close_button.pressed.connect(_on_close_pressed)
    _apply_theme_overrides()

func display_broadcast(data: Dictionary):
    title_label.text = data.get("title", "Radio Update")
    body_label.text = data.get("text", "")
    visible = true
    panel.modulate = Color(0.1, 0.1, 0.1, 0.9)
    if close_button:
        close_button.grab_focus()

func _on_close_pressed():
    visible = false

func _unhandled_input(event):
    if !visible:
        return
    if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
        _on_close_pressed()
        get_viewport().set_input_as_handled()

func _apply_theme_overrides():
    if title_label:
        title_label.add_theme_color_override("font_color", Color.WHITE)
    if body_label:
        body_label.add_theme_color_override("font_color", Color.SILVER)
        body_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    if close_button:
        close_button.text = "Close"
