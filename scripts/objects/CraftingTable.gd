extends Area2D
class_name CraftingTable

@export var prompt_text: String = "Press [I] to craft"

@onready var prompt_label: Label = $PromptLabel

var _player_in_range: bool = false
var _crafting_panel: CraftingPanel

func _ready():
    monitoring = true
    monitorable = true
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    set_process_unhandled_input(true)

    if prompt_label:
        prompt_label.visible = false
        prompt_label.text = prompt_text

    _resolve_dependencies()

func _resolve_dependencies():
    var root = get_tree().get_root()
    if root == null:
        return
    var panel_node = root.get_node_or_null("Main/UI/CraftingPanel")
    _crafting_panel = panel_node if panel_node is CraftingPanel else null

func _unhandled_input(event):
    if !_player_in_range:
        return
    if !event.is_action_pressed("interact") or event.is_echo():
        return
    _handle_interaction()
    get_viewport().set_input_as_handled()

func _handle_interaction():
    if _crafting_panel == null:
        _resolve_dependencies()
    if _crafting_panel:
        _crafting_panel.open_panel()
    else:
        print("🛠️ Crafting table is offline")

func _on_body_entered(body):
    if body is Player:
        _player_in_range = true
        if prompt_label:
            prompt_label.visible = true

func _on_body_exited(body):
    if body is Player:
        _player_in_range = false
        if prompt_label:
            prompt_label.visible = false
        if _crafting_panel and _crafting_panel.visible:
            _crafting_panel.close_panel()
