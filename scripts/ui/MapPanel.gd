# MapPanel.gd overview:
# - Purpose: toggle the expedition map overlay, present route options, and reflect checkpoint progress.
# - Sections: onready caches widgets, ready resolves GameManager + signals, helpers refresh option slots and completed lists, input toggles visibility.
extends Control
class_name MapPanel

const GameManager = preload("res://scripts/GameManager.gd")

const OPTION_BUTTON_LABEL_SELECT := "Select Route"
const OPTION_BUTTON_LABEL_SELECTED := "Selected"
const OPTION_BUTTON_LABEL_COMPLETE := "Journey Complete"

@onready var backdrop: Panel = $Backdrop
@onready var checkpoint_label: Label = $Backdrop/Margin/Content/CheckpointLabel
@onready var option_header_label: Label = $Backdrop/Margin/Content/OptionHeader
@onready var option_container: VBoxContainer = $Backdrop/Margin/Content/OptionContainer
@onready var option_a_title: Label = $Backdrop/Margin/Content/OptionContainer/OptionA/OptionMarginA/OptionVBoxA/OptionATitle
@onready var option_a_details: Label = $Backdrop/Margin/Content/OptionContainer/OptionA/OptionMarginA/OptionVBoxA/OptionADetails
@onready var option_a_summary: Label = $Backdrop/Margin/Content/OptionContainer/OptionA/OptionMarginA/OptionVBoxA/OptionASummary
@onready var option_a_button: Button = $Backdrop/Margin/Content/OptionContainer/OptionA/OptionMarginA/OptionVBoxA/OptionAButton
@onready var option_b_title: Label = $Backdrop/Margin/Content/OptionContainer/OptionB/OptionMarginB/OptionVBoxB/OptionBTitle
@onready var option_b_details: Label = $Backdrop/Margin/Content/OptionContainer/OptionB/OptionMarginB/OptionVBoxB/OptionBDetails
@onready var option_b_summary: Label = $Backdrop/Margin/Content/OptionContainer/OptionB/OptionMarginB/OptionVBoxB/OptionBSummary
@onready var option_b_button: Button = $Backdrop/Margin/Content/OptionContainer/OptionB/OptionMarginB/OptionVBoxB/OptionBButton
@onready var completed_header_label: Label = $Backdrop/Margin/Content/CompletedHeader
@onready var completed_list: VBoxContainer = $Backdrop/Margin/Content/CompletedList
@onready var completed_placeholder: Label = $Backdrop/Margin/Content/CompletedList/CompletedPlaceholder
@onready var hint_label: Label = $Backdrop/Margin/Content/HintLabel
@onready var close_button: Button = $Backdrop/Margin/Content/ButtonRow/CloseButton

var game_manager: GameManager
var _state: Dictionary = {}
var _option_widgets: Array = []

func _ready():
    visible = false
    set_process_unhandled_input(true)
    _apply_theme_overrides()
    _cache_option_widgets()
    _resolve_game_manager()
    if option_a_button:
        option_a_button.pressed.connect(_on_option_button_pressed.bind(0))
    if option_b_button:
        option_b_button.pressed.connect(_on_option_button_pressed.bind(1))
    if close_button:
        close_button.pressed.connect(_close_panel)
    _refresh_state()

func _unhandled_input(event):
    if event.is_action_pressed("map_toggle") and !event.is_echo():
        if visible:
            _close_panel()
        else:
            _open_panel()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("ui_cancel") and visible and !event.is_echo():
        _close_panel()
        get_viewport().set_input_as_handled()

func _open_panel():
    visible = true
    _refresh_state()
    if close_button:
        close_button.grab_focus()

func _close_panel():
    visible = false

func _apply_theme_overrides():
    if backdrop:
        var panel_style := StyleBoxFlat.new()
        panel_style.bg_color = Color(0.07, 0.08, 0.1, 0.95)
        panel_style.border_color = Color(0.3, 0.34, 0.42, 1.0)
        panel_style.border_width_left = 2
        panel_style.border_width_top = 2
        panel_style.border_width_right = 2
        panel_style.border_width_bottom = 2
        panel_style.set_corner_radius_all(12)
        backdrop.add_theme_stylebox_override("panel", panel_style)
    if option_header_label:
        option_header_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
    if completed_header_label:
        completed_header_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
    if hint_label:
        hint_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
    for panel in [
        option_a_title.get_parent().get_parent().get_parent() if option_a_title else null,
        option_b_title.get_parent().get_parent().get_parent() if option_b_title else null
    ]:
        if panel and panel is PanelContainer:
            var slot_style := StyleBoxFlat.new()
            slot_style.bg_color = Color(0.1, 0.12, 0.16, 0.92)
            slot_style.border_color = Color(0.3, 0.34, 0.42, 1.0)
            slot_style.border_width_left = 1
            slot_style.border_width_top = 1
            slot_style.border_width_right = 1
            slot_style.border_width_bottom = 1
            slot_style.set_corner_radius_all(10)
            panel.add_theme_stylebox_override("panel", slot_style)
    for button in [option_a_button, option_b_button, close_button]:
        if button:
            button.focus_mode = Control.FOCUS_ALL

func _cache_option_widgets():
    _option_widgets = [
        {
            "title": option_a_title,
            "details": option_a_details,
            "summary": option_a_summary,
            "button": option_a_button,
            "panel": option_a_title.get_parent().get_parent().get_parent() if option_a_title else null
        },
        {
            "title": option_b_title,
            "details": option_b_details,
            "summary": option_b_summary,
            "button": option_b_button,
            "panel": option_b_title.get_parent().get_parent().get_parent() if option_b_title else null
        }
    ]

func _resolve_game_manager():
    var tree = get_tree()
    if tree == null:
        return
    var root = tree.get_root()
    if root == null:
        return
    var candidate: Node = root.get_node_or_null("Main/GameManager")
    if candidate is GameManager:
        game_manager = candidate
        if game_manager.has_signal("expedition_state_changed"):
            game_manager.expedition_state_changed.connect(_on_expedition_state_changed)
        if game_manager.has_signal("game_mode_changed"):
            game_manager.game_mode_changed.connect(_on_game_mode_changed)
        _state = game_manager.get_expedition_state()

func _on_expedition_state_changed(state: Dictionary):
    _state = state.duplicate(true)
    _refresh_state()

func _on_game_mode_changed(_mode: String):
    _refresh_state()

func _on_option_button_pressed(index: int):
    if game_manager == null:
        return
    var result = game_manager.select_travel_option(index)
    if !result.get("success", false):
        _refresh_state()
        return
    _state = game_manager.get_expedition_state()
    _refresh_state()

func _refresh_state():
    if game_manager != null:
        _state = game_manager.get_expedition_state()
    if game_manager != null and !game_manager.is_adventure_mode():
        var empty: Dictionary = {}
        _refresh_checkpoint_label(empty)
        _refresh_option_slots(empty)
        _refresh_completed_routes(empty)
        _refresh_hint(empty)
        return
    var state := _state
    _refresh_checkpoint_label(state)
    _refresh_option_slots(state)
    _refresh_completed_routes(state)
    _refresh_hint(state)

func _refresh_checkpoint_label(state: Dictionary):
    if checkpoint_label == null:
        return
    if state.is_empty():
        if game_manager != null and !game_manager.is_adventure_mode():
            checkpoint_label.text = "Adventure mode required"
        else:
            checkpoint_label.text = "Map offline"
        return
    if state.get("journey_complete", false):
        var total = int(state.get("total_checkpoints", 8))
        checkpoint_label.text = "Journey complete (%d/%d checkpoints)" % [total, total]
        return
    var current = int(state.get("current_checkpoint", 1))
    var total_points = int(state.get("total_checkpoints", 8))
    checkpoint_label.text = "Checkpoint %d of %d" % [clamp(current, 1, total_points), max(total_points, 1)]

func _refresh_option_slots(state: Dictionary):
    var options: Array = state.get("options", []) if typeof(state) == TYPE_DICTIONARY else []
    var selected_index = int(state.get("selected_option_index", -1)) if typeof(state) == TYPE_DICTIONARY else -1
    var journey_complete = bool(state.get("journey_complete", false))
    for i in range(_option_widgets.size()):
        var widget: Dictionary = _option_widgets[i]
        var visible_option := i < options.size()
        var title_label: Label = widget.get("title")
        var details_label: Label = widget.get("details")
        var summary_label: Label = widget.get("summary")
        var button: Button = widget.get("button")
        var panel: Control = widget.get("panel")
        if panel:
            panel.visible = visible_option
        if title_label:
            title_label.get_parent().visible = visible_option
        if !visible_option:
            if button:
                button.text = OPTION_BUTTON_LABEL_SELECT
                button.disabled = true
            continue
        var option: Dictionary = options[i]
        var label = String(option.get("label", "Route"))
        var letter = char(65 + i)
        if title_label:
            title_label.text = "%s) %s" % [letter, label]
        var hours = float(option.get("travel_hours", GameManager.TRAVEL_HOURS_MIN))
        var min_hours = float(option.get("hours_min", GameManager.TRAVEL_HOURS_MIN))
        var max_hours = float(option.get("hours_max", GameManager.TRAVEL_HOURS_MAX))
        var rest_cost = float(option.get("rest_cost_percent", GameManager.TRAVEL_REST_COST_PERCENT))
        var calories = int(round(option.get("calorie_cost", GameManager.TRAVEL_CALORIE_COST)))
        var hazard = String(option.get("hazard_tier", "watchful")).capitalize()
        var climate = String(option.get("temperature_band", "temperate")).capitalize()
        if details_label:
            var travel_line = "Travel %.1fh | Range %.1f-%.1fh" % [hours, min_hours, max_hours]
            var cost_line = "-%s%% energy | -%d cal | Hazard %s | Climate %s" % [
                _format_percent(rest_cost),
                calories,
                hazard,
                climate
            ]
            details_label.text = "%s\n%s" % [travel_line, cost_line]
        if summary_label:
            var summary = String(option.get("summary", "Route intel pending."))
            var fragments: PackedStringArray = []
            if summary.is_empty():
                fragments.append("Route intel pending.")
            else:
                fragments.append(summary)
            var stats: PackedStringArray = []
            stats.append("Hazard: %s" % hazard)
            stats.append("Climate: %s" % climate)
            if option.get("fishing_allowed", false):
                stats.append("Fishing access")
            if option.get("shelter_from_rain", false):
                stats.append("Sheltered")
            fragments.append(" | ".join(stats))
            summary_label.text = "\n".join(fragments)
        if button:
            if journey_complete:
                button.text = OPTION_BUTTON_LABEL_COMPLETE
                button.disabled = true
            else:
                var is_selected = selected_index == i
                button.text = OPTION_BUTTON_LABEL_SELECTED if is_selected else OPTION_BUTTON_LABEL_SELECT
                button.disabled = is_selected

func _refresh_completed_routes(state: Dictionary):
    if completed_list == null:
        return
    for child in completed_list.get_children():
        if child != completed_placeholder:
            child.queue_free()
    if completed_placeholder:
        completed_placeholder.show()
    if state.is_empty():
        return
    var routes: Array = state.get("completed_routes", [])
    if routes.is_empty():
        return
    if completed_placeholder:
        completed_placeholder.hide()
    for i in range(routes.size()):
        var route = routes[i]
        if typeof(route) != TYPE_DICTIONARY:
            continue
        var label = String(route.get("label", "Route"))
        var hours = float(route.get("travel_hours", GameManager.TRAVEL_HOURS_MIN))
        var checkpoint = int(route.get("checkpoint_arrived", i + 1))
        var entry := Label.new()
        entry.text = "%d. %s (%.1fh | Reached CP %d)" % [i + 1, label, hours, checkpoint]
        entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        entry.add_theme_color_override("font_color", Color(0.82, 0.85, 0.9))
        completed_list.add_child(entry)

func _refresh_hint(state: Dictionary):
    if hint_label == null:
        return
    if state.is_empty():
        if game_manager != null and !game_manager.is_adventure_mode():
            hint_label.text = "Switch to Adventure mode to plot the evacuation route."
        else:
            hint_label.text = "Press M to toggle map"
        return
    if state.get("journey_complete", false):
        hint_label.text = "All checkpoints reached. Press M or Close to return."
    else:
        hint_label.text = "Select a route, then queue Travel in the task menu."

func _format_percent(value: float) -> String:
    return "%s" % String.num(value, 1).rstrip("0").rstrip(".")
