# WoodStove.gd overview:
# - Purpose: allow players to open the stove panel when nearby and keep prompts updated with the correct keybinding.
# - Sections: exports store prompt text, lifecycle hooks manage overlap state, helpers resolve UI references and format prompts.
extends Area2D
class_name WoodStove

@export var prompt_text: String = "Press [%s] to manage stove"

# Panel lookup order: absolute path, scene-local path (kept for tests relying on Main as root).
const PANEL_PATHS := [
    NodePath("/root/Main/UI/WoodStovePanel"),
    NodePath("Main/UI/WoodStovePanel")
]
const PANEL_GROUP := "wood_stove_panel"

@onready var prompt_label: Label = $PromptLabel

var _player_in_range: bool = false
var _panel: Control = null
var _prompt_template: String = ""
var _panel_missing_logged: bool = false

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
    _resolve_panel()

func _resolve_panel():
    # - Role: cache the panel reference once located so repeated presses stay instant.
    _panel = _locate_panel()
    if _panel:
        _panel_missing_logged = false

func _locate_panel() -> Control:
    # - Purpose: gather the stove panel via all known hints (path, group, or name) so interaction always succeeds.
    var tree := get_tree()
    if tree == null:
        return null
    var root := tree.get_root()
    if root == null:
        return null

    for path in PANEL_PATHS:
        var panel_node: Node = root.get_node_or_null(path)
        if _is_valid_panel(panel_node):
            return panel_node

    var group_nodes := tree.get_nodes_in_group(PANEL_GROUP)
    for candidate in group_nodes:
        if _is_valid_panel(candidate):
            return candidate

    var named_match: Node = root.find_child("WoodStovePanel", true, false)
    if _is_valid_panel(named_match):
        return named_match

    return null

func _is_valid_panel(candidate: Node) -> bool:
    # - Purpose: confirm a candidate node can open the stove panel with enterprise-safe checks.
    return candidate is Control and candidate.has_method("open_panel")

func _unhandled_input(event):
    if !_player_in_range:
        return
    if !event.is_action_pressed("interact") or event.is_echo():
        return
    _handle_interaction()
    get_viewport().set_input_as_handled()

func _handle_interaction():
    if !is_instance_valid(_panel):
        _panel = null
    if _panel == null:
        _resolve_panel()
    if _panel and _panel.has_method("open_panel"):
        _panel.call("open_panel")
        _panel_missing_logged = false
    elif !_panel_missing_logged:
        _panel_missing_logged = true
        print("🔥 Wood stove panel unavailable")

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
    var template = _prompt_template if !_prompt_template.is_empty() else "Press [%s] to manage stove"
    if template.find("%s") != -1:
        return template % key_label
    return template

func _on_body_entered(body):
    if body is Player:
        _player_in_range = true
        if _panel == null:
            _resolve_panel()
        if prompt_label:
            prompt_label.visible = true

func _on_body_exited(body):
    if body is Player:
        _player_in_range = false
        if prompt_label:
            prompt_label.visible = false
        if _panel and _panel.visible and _panel.has_method("close_panel"):
            _panel.call("close_panel")
