# PatrolGuide.gd overview:
# - Purpose: interactive book that opens the Firetower Patrol Guide when inspected.
# - Sections: exports tune prompt copy, overlap handlers toggle the prompt, helpers resolve UI/game data and show the guide.
extends Area2D
class_name PatrolGuide

const GameManager = preload("res://scripts/GameManager.gd")
const ActionPopupPanel = preload("res://scripts/ui/ActionPopupPanel.gd")

@export var prompt_text: String = "Press [%s] to read"

@onready var prompt_label: Label = $PromptLabel

var _player_in_range: bool = false
var _prompt_template: String = ""
var _game_manager: GameManager
var _info_popup: ActionPopupPanel

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

func _unhandled_input(event):
    if !_player_in_range:
        return
    if !event.is_action_pressed("interact") or event.is_echo():
        return
    _handle_interaction()
    get_viewport().set_input_as_handled()

func _handle_interaction():
    if _game_manager == null or _info_popup == null:
        _resolve_dependencies()
    if _game_manager == null or _info_popup == null:
        return
    var payload = _game_manager.get_patrol_guide_payload()
    if payload.is_empty():
        return
    var title = String(payload.get("title", "Patrol Guide"))
    var sections: Array = payload.get("sections", [])
    if sections.is_empty():
        var lines: PackedStringArray = payload.get("lines", PackedStringArray([]))
        if !lines.is_empty():
            _info_popup.show_message(title, lines)
    else:
        _info_popup.show_sections(title, sections)

func _resolve_dependencies():
    var root = get_tree().get_root()
    if root == null:
        return
    var manager_node = root.get_node_or_null("Main/GameManager")
    _game_manager = manager_node as GameManager if manager_node is GameManager else null

    var popup_node = root.get_node_or_null("Main/UI/ActionPopupPanel")
    _info_popup = popup_node as ActionPopupPanel if popup_node is ActionPopupPanel else null

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
    var template = _prompt_template if !_prompt_template.is_empty() else "Press [%s] to read"
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
