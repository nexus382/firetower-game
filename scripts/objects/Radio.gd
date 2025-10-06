extends Area2D
class_name Radio

@export var prompt_text: String = "Press [I] to tune"
@export var static_text: String = "Only static crackles tonight."

@onready var prompt_label: Label = $PromptLabel

var _player_in_range: bool = false
var _game_manager: GameManager
var _radio_panel: RadioPanel

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
    _game_manager = root.get_node_or_null("Main/GameManager")
    _radio_panel = root.get_node_or_null("Main/UI/RadioPanel")

func _unhandled_input(event):
    if !_player_in_range:
        return
    if !event.is_action_pressed("interact") or event.is_echo():
        return
    _handle_interaction()
    get_viewport().set_input_as_handled()

func _handle_interaction():
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
        _show_panel_with_message({
            "title": "%s - Day %d" % [title, report.get("day", 0)],
            "text": text
        })
    else:
        _show_panel_with_message({
            "title": "Radio Static",
            "text": static_text
        })

func _show_panel_with_message(payload: Dictionary):
    if _radio_panel:
        _radio_panel.display_broadcast(payload)
    else:
        print("📻 %s -> %s" % [payload.get("title", "Radio"), payload.get("text", "")])

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
