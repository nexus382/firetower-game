extends Area2D
class_name CraftingTable

@export var prompt_text: String = "Press [%s] to craft"

const CraftingPanelScript := preload("res://scripts/ui/CraftingPanel.gd")
const CRAFTING_PANEL_PATH := NodePath("Main/UI/CraftingPanel")

@onready var prompt_label: Label = $PromptLabel

var _player_in_range: bool = false
var _crafting_panel: Control = null
var _prompt_template: String = ""

func _ready():
    monitoring = true
    monitorable = true
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    set_process_unhandled_input(true)

    _prompt_template = prompt_text
    if prompt_label:
        prompt_label.visible = false
    _update_prompt_text()

    _resolve_dependencies()

func _resolve_dependencies():
    var root = get_tree().get_root()
    if root == null:
        return
    var panel_node = root.get_node_or_null(CRAFTING_PANEL_PATH)
    if panel_node and panel_node is Control and panel_node.get_script() == CraftingPanelScript:
        _crafting_panel = panel_node
    else:
        _crafting_panel = null

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

func _update_prompt_text():
    var display = _format_prompt_text(_resolve_interact_key_label())
    prompt_text = display
    if prompt_label:
        prompt_label.text = display

func _resolve_interact_key_label() -> String:
    var fallback = "E"
    var events = InputMap.action_get_events("interact")
    for evt in events:
        if evt is InputEventKey:
            var code = evt.keycode
            if code == Key.KEY_UNKNOWN or code == 0:
                code = evt.physical_keycode
            if code != Key.KEY_UNKNOWN and code != 0:
                var label = OS.get_keycode_string(code)
                if !label.is_empty():
                    return label.to_upper()
    return fallback

func _format_prompt_text(key_label: String) -> String:
    var template = _prompt_template if !_prompt_template.is_empty() else "Press [%s] to craft"
    if template.find("%s") != -1:
        return template % key_label
    return template

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
