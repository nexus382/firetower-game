# Radio.gd overview:
# - Purpose: interactive tower radio that surfaces broadcasts or static when tuned.
# - Sections: exports set prompt copy, overlap signals toggle availability, helpers fetch GameManager reports and open UI panel.
extends Area2D
class_name Radio

const ATTENTION_ON_SECONDS := 1.5
const ATTENTION_OFF_SECONDS := 0.2
const ActionPopupPanelClass := preload("res://scripts/ui/ActionPopupPanel.gd")

@export var prompt_text: String = "Press [%s] to tune"
@export var static_text: String = "Only static crackles tonight."

@onready var prompt_label: Label = $PromptLabel
@onready var attention_label: Label = $AttentionLabel

# Tracks when the player can trigger the interaction prompt.
var _player_in_range: bool = false
var _game_manager: GameManager = null
var _radio_panel: Control
var _tutorial_popup: ActionPopupPanelClass
var _prompt_template: String = ""
var _attention_timer: Timer
var _attention_showing: bool = false
var _attention_active: bool = false

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

    if attention_label:
        attention_label.visible = false

    _attention_timer = Timer.new()
    _attention_timer.one_shot = true
    add_child(_attention_timer)
    _attention_timer.timeout.connect(_on_attention_timer_timeout)

    _resolve_dependencies()

func _resolve_dependencies():
    # Lazy-load references so the radio still works if the scene tree shifts.
    var root = get_tree().get_root()
    if root == null:
        return

    var manager_node = root.get_node_or_null("Main/GameManager")
    _game_manager = manager_node as GameManager if manager_node is GameManager else null
    if _game_manager and !_game_manager.is_connected("radio_attention_changed", Callable(self, "_on_radio_attention_changed")):
        _game_manager.radio_attention_changed.connect(_on_radio_attention_changed)
        _on_radio_attention_changed(_game_manager.has_unheard_radio_message())

    var panel_node = root.get_node_or_null("Main/UI/RadioPanel")
    _radio_panel = panel_node if panel_node is Control else null

    var popup_node = root.get_node_or_null("Main/UI/ActionPopupPanel")
    _tutorial_popup = popup_node as ActionPopupPanelClass if popup_node is ActionPopupPanelClass else null

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

    if _game_manager.should_show_radio_tip():
        _show_radio_tip()
        _game_manager.mark_radio_tip_shown()

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
        var blocks: Array = []
        var base_text = String(broadcast.get("text", ""))
        if !base_text.is_empty():
            blocks.append(base_text)

        var claim_report = _game_manager.claim_daily_supply_drop()
        # Append structured supply note after the claim so reminders stay accurate when the cache is secured.
        var supply_note: Dictionary = report.get("daily_supply_note", {})
        var supply_lines: PackedStringArray = supply_note.get("lines", PackedStringArray([]))
        if claim_report.get("claimed", false) and !supply_lines.is_empty():
            var trimmed := PackedStringArray([])
            for line in supply_lines:
                if line.find("Dispatch left a fresh hamper") != -1:
                    continue
                trimmed.append(line)
            supply_lines = trimmed
        if supply_lines.size() > 0:
            var note_title = String(supply_note.get("title", ""))
            var note_body = "\n\n".join(supply_lines)
            var supply_block = note_body if note_title.is_empty() else "%s:\n%s" % [note_title, note_body]
            blocks.append(supply_block)

        if claim_report.get("had_cache", false):
            if claim_report.get("claimed", false):
                var summary = String(claim_report.get("summary_text", ""))
                if !summary.is_empty():
                    blocks.append("Hamper Secured:\n%s" % summary)
            else:
                var miss_reason = String(claim_report.get("reason", ""))
                if !miss_reason.is_empty():
                    var friendly_reason = miss_reason.replace("_", " ").capitalize()
                    blocks.append("Hamper Status: %s" % friendly_reason)

        var text = "\n\n".join(blocks)
        if text.is_empty():
            text = static_text

        var day_value = report.get("day", 0)
        _show_panel_with_message({
            "title": "{0} - Day {1}".format([title, day_value]),
            "text": text
        })
        _game_manager.mark_radio_message_heard()
    else:
        _show_panel_with_message({
            "title": "Radio Static",
            "text": static_text
        })
        _on_radio_attention_changed(false)

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

func _show_radio_tip():
    if _tutorial_popup == null:
        return
    var lines: PackedStringArray = [
        "Welcome to the tower, lookout—check the radio each morning for valley updates.",
        "Some broadcasts bring windfalls, others warn of danger—missing one can cost you dearly.",
        "Stay tuned and stay safe out there."
    ]
    _tutorial_popup.show_message("Daily Radio Brief", lines)

func _on_radio_attention_changed(active: bool):
    _set_attention_active(active)

func _set_attention_active(active: bool):
    if _attention_active == active:
        return
    _attention_active = active
    if !_attention_active:
        if _attention_timer:
            _attention_timer.stop()
        if attention_label:
            attention_label.visible = false
        return
    _attention_showing = false
    _queue_attention_pulse(true)

func _queue_attention_pulse(show_now: bool):
    if !_attention_active or attention_label == null or _attention_timer == null:
        return
    _attention_showing = show_now
    attention_label.visible = show_now
    var wait_time = ATTENTION_ON_SECONDS if show_now else ATTENTION_OFF_SECONDS
    _attention_timer.start(wait_time)

func _on_attention_timer_timeout():
    if !_attention_active or attention_label == null or _attention_timer == null:
        return
    _attention_showing = !_attention_showing
    attention_label.visible = _attention_showing
    var wait_time = ATTENTION_ON_SECONDS if _attention_showing else ATTENTION_OFF_SECONDS
    _attention_timer.start(wait_time)

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
