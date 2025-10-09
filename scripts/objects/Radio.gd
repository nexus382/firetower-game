# Radio.gd overview:
# - Purpose: interactive tower radio that surfaces broadcasts or static when tuned.
# - Sections: exports set prompt copy, overlap signals toggle availability, helpers fetch GameManager reports and open UI panel.
extends Area2D
class_name Radio

@export var prompt_text: String = "Press [%s] to tune"
@export var static_text: String = "Only static crackles tonight."

@onready var prompt_label: Label = $PromptLabel

# Tracks when the player can trigger the interaction prompt.
var _player_in_range: bool = false
var _game_manager: GameManager = null
var _radio_panel: Control
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
    # Lazy-load references so the radio still works if the scene tree shifts.
    var root = get_tree().get_root()
    if root == null:
        return

    var manager_node = root.get_node_or_null("Main/GameManager")
    _game_manager = manager_node as GameManager if manager_node is GameManager else null

    var panel_node = root.get_node_or_null("Main/UI/RadioPanel")
    _radio_panel = panel_node if panel_node is Control else null

func _unhandled_input(event):
    if !_player_in_range:
        return
    if !event.is_action_pressed("interact") or event.is_echo():
        return
    _handle_interaction()
    get_viewport().set_input_as_handled()

func _handle_interaction():
    # Make sure we always talk to a fresh GameManager/UI before resolving broadcasts.
    if _game_manager == null or _radio_panel == null:
        _resolve_dependencies()
    if _game_manager == null:
        _show_panel_with_message({
            "title": "Radio Offline",
            "text": "The base station stays silent."
        })
        return

    var report = _game_manager.request_radio_broadcast()
    if !report.get("success", false):
        _show_panel_with_message({
            "title": "Radio Offline",
            "text": "The base station stays silent."
        })
        return

    var broadcast: Dictionary = report.get("broadcast", {})
    if report.get("has_message", false) and !broadcast.is_empty():
        var title = broadcast.get("title", "Radio Update")
        var text = broadcast.get("text", static_text)
        var day_value = report.get("day", 0)
        _show_panel_with_message({
            "title": "{0} - Day {1}".format([title, day_value]),
            "text": text
        })
    else:
        _show_panel_with_message({
            "title": "Radio Static",
            "text": static_text
        })

func _show_panel_with_message(payload: Dictionary):
    if _radio_panel and _radio_panel.has_method("display_broadcast"):
        _radio_panel.display_broadcast(payload)
    else:
        var title = payload.get("title", "Radio")
        var message = payload.get("text", "")
        print("📻 {0} -> {1}".format(title, message))

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
    var template = _prompt_template if !_prompt_template.is_empty() else "Press [%s] to tune"
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
