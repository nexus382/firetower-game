# ModeSelectPanel.gd overview:
# - Purpose: prompt the player to choose Survival or Adventure mode at startup.
# - Sections: onready caches widgets, ready hook wires buttons, helpers preview/apply selections.
extends Control
class_name ModeSelectPanel

const GameManager = preload("res://scripts/GameManager.gd")
const ActionPopupPanel = preload("res://scripts/ui/ActionPopupPanel.gd")

const SURVIVAL_MODE_ID := GameManager.GAME_MODE_SURVIVAL
const ADVENTURE_MODE_ID := GameManager.GAME_MODE_ADVENTURE

const SURVIVAL_DESCRIPTION := "Survival: Hold the tower, forge and search locally, and outlast the horde."
const ADVENTURE_DESCRIPTION := "Adventure: Gear up, travel checkpoints, and push toward the evac convoy."

@export var survival_button_path: NodePath
@export var adventure_button_path: NodePath
@export var title_label_path: NodePath
@export var description_label_path: NodePath
@export var info_popup_path: NodePath

@onready var survival_button: Button = null
@onready var adventure_button: Button = null
@onready var title_label: Label = null
@onready var description_label: Label = null
@onready var info_popup: ActionPopupPanel = null

var game_manager: GameManager

func _ready():
    visible = true
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_process_unhandled_input(true)
    _resolve_nodes()
    _resolve_game_manager()
    _apply_theme_overrides()
    _wire_buttons()
    _refresh_selection(game_manager if game_manager != null else SURVIVAL_MODE_ID)
    call_deferred("_grab_initial_focus")

func _unhandled_input(event):
    if !visible:
        return
    if event.is_action_pressed("ui_cancel") and !event.is_echo():
        get_viewport().set_input_as_handled()

func _wire_buttons():
    if survival_button:
        survival_button.pressed.connect(_on_survival_pressed)
        survival_button.focus_entered.connect(_on_survival_preview)
        survival_button.mouse_entered.connect(_on_survival_preview)
    if adventure_button:
        adventure_button.pressed.connect(_on_adventure_pressed)
        adventure_button.focus_entered.connect(_on_adventure_preview)
        adventure_button.mouse_entered.connect(_on_adventure_preview)

func _resolve_nodes():
    if survival_button_path != NodePath(""):
        survival_button = get_node_or_null(survival_button_path)
    if adventure_button_path != NodePath(""):
        adventure_button = get_node_or_null(adventure_button_path)
    if title_label_path != NodePath(""):
        title_label = get_node_or_null(title_label_path)
    if description_label_path != NodePath(""):
        description_label = get_node_or_null(description_label_path)
    if info_popup_path != NodePath(""):
        info_popup = get_node_or_null(info_popup_path)

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
        if game_manager.has_signal("game_mode_changed"):
            game_manager.game_mode_changed.connect(_on_game_mode_changed)

    if info_popup == null:
        _resolve_info_popup(root)

func _resolve_info_popup(root: Node):
    if root == null:
        return
    var node = root.get_node_or_null("Main/UI/ActionPopupPanel")
    if node is ActionPopupPanel:
        info_popup = node

func _grab_initial_focus():
    if survival_button and survival_button.is_visible_in_tree():
        survival_button.grab_focus()
    elif adventure_button and adventure_button.is_visible_in_tree():
        adventure_button.grab_focus()

func _apply_theme_overrides():
    if title_label:
        title_label.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0))
    if description_label:
        description_label.add_theme_color_override("font_color", Color(0.85, 0.87, 0.92))
        description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    for button in [survival_button, adventure_button]:
        if button:
            button.focus_mode = Control.FOCUS_ALL
            button.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))

func _on_survival_pressed():
    _apply_selection(SURVIVAL_MODE_ID)

func _on_adventure_pressed():
    _apply_selection(ADVENTURE_MODE_ID)

func _on_survival_preview():
    _refresh_description(SURVIVAL_MODE_ID)

func _on_adventure_preview():
    _refresh_description(ADVENTURE_MODE_ID)

func _apply_selection(mode: String):
    if game_manager:
        mode = game_manager.set_game_mode(mode)
        _refresh_selection(mode)
        _show_mode_popup(mode)
    else:
        _refresh_selection(mode)
        _show_mode_popup(mode)
    hide()

func _on_game_mode_changed(mode: String):
    _refresh_selection(mode)

func _refresh_selection(mode: String):
    _refresh_description(mode)
    if survival_button:
        survival_button.button_pressed = mode == SURVIVAL_MODE_ID
    if adventure_button:
        adventure_button.button_pressed = mode == ADVENTURE_MODE_ID

func _refresh_description(mode: String):
    if title_label and title_label.text.is_empty():
        title_label.text = "Select Game Mode"
    if description_label == null:
        return
    match mode:
        ADVENTURE_MODE_ID:
            description_label.text = ADVENTURE_DESCRIPTION
        _:
            description_label.text = SURVIVAL_DESCRIPTION

func _show_mode_popup(mode: String):
    if info_popup == null:
        return
    var payload: Dictionary = {}
    if game_manager:
        payload = game_manager.get_mode_briefing(mode)
    if payload.is_empty():
        payload = {
            "title": "Mode Selected",
            "sections": [
                {"title": "Mode", "lines": [mode.capitalize()]}
            ]
        }
    var title = String(payload.get("title", ""))
    var sections: Array = payload.get("sections", [])
    if sections.is_empty():
        var lines: PackedStringArray = payload.get("lines", PackedStringArray([]))
        if !lines.is_empty():
            info_popup.show_message(title, lines)
    else:
        info_popup.show_sections(title, sections)
