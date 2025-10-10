# ActionPopupPanel.gd overview:
# - Purpose: provide reusable modal popups for action summaries and alerts.
# - Sections: onready caches widgets, helpers format line groups, and public methods reveal messages.
extends Control
class_name ActionPopupPanel

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var body_text: RichTextLabel = $Panel/Margin/VBox/BodyText
@onready var close_button: Button = $Panel/Margin/VBox/ButtonRow/CloseButton

func _ready():
    visible = false
    set_process_unhandled_input(true)
    if close_button:
        close_button.pressed.connect(hide_panel)
    _apply_theme_overrides()

func show_message(title: String, lines: PackedStringArray):
    if !is_instance_valid(body_text) or !is_instance_valid(title_label):
        return
    title_label.text = title
    body_text.clear()
    body_text.bbcode_text = _join_lines(lines)
    visible = true
    if close_button:
        close_button.focus_mode = Control.FOCUS_ALL
        close_button.grab_focus()

func show_sections(title: String, sections: Array):
    var lines: PackedStringArray = []
    for section in sections:
        if typeof(section) != TYPE_DICTIONARY:
            continue
        var header = String(section.get("title", ""))
        var items: Array = section.get("lines", [])
        if header != "":
            lines.append("[b]%s[/b]" % header)
        for item in items:
            lines.append("• %s" % item)
        if !items.is_empty():
            lines.append("")
    if !lines.is_empty() and lines[lines.size() - 1] == "":
        lines.remove_at(lines.size() - 1)
    show_message(title, lines)

func hide_panel():
    visible = false

func _unhandled_input(event):
    if !visible:
        return
    if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
        hide_panel()
        get_viewport().set_input_as_handled()

func _join_lines(lines: PackedStringArray) -> String:
    if lines.is_empty():
        return ""
    return "\n".join(lines)

func _apply_theme_overrides():
    if panel:
        var box := StyleBoxFlat.new()
        box.bg_color = Color(0.08, 0.08, 0.08, 1.0)
        box.set_corner_radius_all(8)
        box.set_border_width_all(2)
        box.border_color = Color(0.25, 0.25, 0.25, 1.0)
        panel.add_theme_stylebox_override("panel", box)
    if title_label:
        title_label.add_theme_color_override("font_color", Color.WHITE)
    if body_text:
        body_text.bbcode_enabled = true
        body_text.add_theme_color_override("default_color", Color(0.9, 0.9, 0.9))
        body_text.autowrap_mode = TextServer.AUTOWRAP_WORD
    if close_button:
        close_button.text = "Close"
        close_button.add_theme_color_override("font_color", Color.WHITE)
