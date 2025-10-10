# CraftingPanel.gd overview:
# - Purpose: display craftable recipes, show requirements, and send craft requests to GameManager.
# - Sections: preloads grab systems, _ready wires UI, helpers rebuild buttons, handle focus, and trigger crafting attempts.
extends Control
class_name CraftingPanel

const InventorySystem = preload("res://scripts/systems/InventorySystem.gd")

# Cache common UI nodes for quick refreshes when recipes change.
@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var recipe_header: Label = $Panel/Margin/VBox/ContentColumns/RecipeColumn/RecipeHeader
@onready var recipe_list: VBoxContainer = $Panel/Margin/VBox/ContentColumns/RecipeColumn/RecipeScroll/RecipeList
@onready var detail_header: Label = $Panel/Margin/VBox/ContentColumns/DetailColumn/DetailHeader
@onready var detail_label: Label = $Panel/Margin/VBox/ContentColumns/DetailColumn/DetailScroll/DetailLabel
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel
@onready var button_row: HBoxContainer = $Panel/Margin/VBox/ButtonRow
@onready var close_button: Button = $Panel/Margin/VBox/ButtonRow/CloseButton

var game_manager: GameManager
var inventory_system: InventorySystem
var _recipes: Dictionary = {}
var _buttons: Dictionary = {}
var _active_recipe: String = ""

func _ready():
    # Initialize the crafting list and link input handlers once the scene is ready.
    visible = false
    set_process_unhandled_input(true)
    if close_button:
        close_button.pressed.connect(close_panel)

    _apply_theme_overrides()
    _resolve_game_manager()
    _load_recipes()
    _build_recipe_list()
    _update_recipe_states()
    _refresh_detail_text()

func open_panel():
    # Refresh data each time the panel opens so new recipes instantly appear.
    if !visible:
        visible = true
        status_label.text = ""
        _load_recipes()
        _build_recipe_list()
        _refresh_detail_text()
        _update_recipe_states()
    if close_button:
        close_button.focus_mode = Control.FOCUS_ALL
    var first_button: Button = _buttons.get(_active_recipe, {}).get("button") if _buttons.has(_active_recipe) else null
    if first_button == null and !_buttons.is_empty():
        var keys = _buttons.keys()
        keys.sort()
        if keys.size() > 0:
            _active_recipe = keys[0]
            first_button = _buttons.get(_active_recipe, {}).get("button")
    if first_button:
        first_button.grab_focus()

func close_panel():
    visible = false

func _unhandled_input(event):
    if !visible:
        return
    if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
        close_panel()
        get_viewport().set_input_as_handled()

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
        inventory_system = game_manager.get_inventory_system()
        if inventory_system:
            inventory_system.item_added.connect(_on_inventory_changed)
            inventory_system.item_consumed.connect(_on_inventory_changed)
    else:
        push_warning("GameManager not available for CraftingPanel")

func _load_recipes():
    if game_manager == null:
        _recipes = {}
        return
    _recipes = game_manager.get_crafting_recipes()

func _build_recipe_list():
    # Rebuild the recipe buttons so costs and focus targets stay accurate.
    if !is_instance_valid(recipe_list):
        return
    for child in recipe_list.get_children():
        child.queue_free()
    _buttons.clear()
    var preserved_active = _active_recipe
    if _recipes.is_empty():
        var placeholder = Label.new()
        placeholder.text = "No recipes available"
        placeholder.add_theme_color_override("font_color", Color.WHITE)
        recipe_list.add_child(placeholder)
        _update_recipe_header()
        return
    var keys = _recipes.keys()
    keys.sort()
    if preserved_active.is_empty() or !keys.has(preserved_active):
        _active_recipe = ""
    for key in keys:
        var recipe: Dictionary = _recipes.get(key, {})
        var recipe_id := String(key)
        var row = HBoxContainer.new()
        row.add_theme_constant_override("separation", 16)
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

        var button = Button.new()
        button.text = recipe.get("display_name", key.capitalize())
        button.focus_mode = Control.FOCUS_ALL
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.size_flags_stretch_ratio = 0.45
        button.pressed.connect(Callable(self, "_attempt_craft").bind(recipe_id))
        button.mouse_entered.connect(Callable(self, "_on_recipe_hovered").bind(recipe_id))
        button.focus_entered.connect(Callable(self, "_on_recipe_hovered").bind(recipe_id))
        row.add_child(button)

        var cost_label = Label.new()
        cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        cost_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
        cost_label.text = _format_recipe_cost(recipe)
        cost_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
        cost_label.add_theme_constant_override("line_separation", 2)
        cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD
        cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        cost_label.size_flags_stretch_ratio = 0.55
        row.add_child(cost_label)

        recipe_list.add_child(row)
        _buttons[key] = {
            "button": button,
            "cost_label": cost_label
        }
        if _active_recipe == "":
            _active_recipe = key
        if preserved_active == key:
            _active_recipe = key
    _update_recipe_header()

func _attempt_craft(recipe_id: String):
    # Delegate crafting to the GameManager and surface a concise status summary.
    if game_manager == null:
        status_label.text = "Crafting offline"
        return
    var result = game_manager.craft_item(recipe_id)
    if !result.get("success", false):
        var reason = result.get("reason", "failed")
        match reason:
            "insufficient_material":
                var need = int(result.get("required", 1))
                var have = int(result.get("available", 0))
                var label = _resolve_material_label(String(result.get("material_id", "")), String(result.get("material_display", "")))
                status_label.text = "Need %d %s (Have %d)" % [need, label, have]
            "insufficient_wood":
                var need = int(result.get("wood_required", 1))
                var have = int(result.get("wood_available", 0))
                var label = _resolve_material_label("wood")
                status_label.text = "Need %d %s (Have %d)" % [need, label, have]
            "material_consume_failed":
                var fail_label = _resolve_material_label(String(result.get("material_id", "")), String(result.get("material_display", "")))
                var needed = int(result.get("required", 0))
                var have = int(result.get("available", 0))
                status_label.text = "Spend %d %s failed (Have %d)" % [max(needed, 0), fail_label, max(have, 0)]
            "exceeds_day":
                var minutes = result.get("minutes_available", 0)
                status_label.text = _format_daybreak_warning(minutes)
            "systems_unavailable":
                status_label.text = "Systems unavailable"
            "recipe_missing":
                status_label.text = "Recipe missing"
            _:
                status_label.text = "Crafting failed"
        _update_recipe_states()
        return
    var name = result.get("display_name", recipe_id.capitalize())
    var end_time = result.get("ended_at_time", "")
    var parts: PackedStringArray = []
    parts.append("Crafted %s" % name)
    var materials: Array = result.get("materials_spent", [])
    if !materials.is_empty():
        for entry in materials:
            var qty = int(entry.get("quantity", 0))
            if qty <= 0:
                continue
            var label = _resolve_material_label(String(entry.get("item_id", "")), String(entry.get("display_name", "")))
            parts.append("-%d %s" % [qty, label])
    else:
        var wood_spent = int(result.get("wood_spent", 0))
        if wood_spent > 0:
            var wood_label = _resolve_material_label("wood")
            parts.append("-%d %s" % [wood_spent, wood_label])
    var rest_spent = result.get("rest_spent_percent", 0.0)
    if rest_spent > 0.0:
        parts.append("-%d%% rest" % int(round(rest_spent)))
    var calories_spent = int(round(result.get("calories_spent", GameManager.CRAFT_CALORIE_COST)))
    if calories_spent > 0:
        parts.append("+%d burn" % calories_spent)
    if end_time != "":
        parts.append("End %s" % end_time)
    status_label.text = " | ".join(parts)
    _active_recipe = recipe_id
    _update_recipe_states()
    _refresh_detail_text()

func _on_recipe_hovered(recipe_id: String):
    if _active_recipe == recipe_id:
        _refresh_detail_text()
        return
    _active_recipe = recipe_id
    _refresh_detail_text()

func _refresh_detail_text():
    # Show the highlighted recipe with duration estimates adjusted for multipliers.
    if !is_instance_valid(detail_label):
        return
    if detail_header:
        detail_header.text = "Build Details"
    if !_recipes.has(_active_recipe):
        detail_label.text = "Select a recipe to view details."
        return
    var recipe: Dictionary = _recipes.get(_active_recipe, {})
    if detail_header:
        detail_header.text = recipe.get("display_name", _active_recipe.capitalize())
    var lines: PackedStringArray = []
    var description = String(recipe.get("description", ""))
    if !description.is_empty():
        lines.append(description)
    var duration = float(recipe.get("hours", 1.0))
    if duration > 0.0:
        var minutes = int(ceil(duration * 60.0 * max(_resolve_multiplier(), 0.01)))
        lines.append("Takes %s" % _format_duration(minutes))
    lines.append("Burns %d cal" % int(round(GameManager.CRAFT_CALORIE_COST)))
    var rest_cost = float(recipe.get("rest_cost_percent", 0.0))
    if rest_cost > 0.0:
        lines.append("Costs %d%% rest" % int(round(rest_cost)))
    var cost: Dictionary = recipe.get("cost", {})
    if !cost.is_empty():
        var keys = cost.keys()
        keys.sort()
        for key in keys:
            var amount = int(cost.get(key, 0))
            if amount <= 0:
                continue
            var label = _resolve_material_label(String(key))
            var stock = inventory_system.get_item_count(key) if inventory_system else 0
            lines.append("Needs %d %s (Stock %d)" % [amount, label, stock])
    detail_label.text = "\n".join(lines)

func _update_recipe_states():
    if _buttons.is_empty():
        return
    for key in _buttons.keys():
        var recipe: Dictionary = _recipes.get(key, {})
        var entry: Dictionary = _buttons.get(key, {})
        var button: Button = entry.get("button")
        if button:
            button.disabled = !_has_materials_for_recipe(recipe)
        var cost_label: Label = entry.get("cost_label")
        if cost_label:
            cost_label.text = _format_recipe_cost(recipe)

func _format_recipe_cost(recipe: Dictionary) -> String:
    var entries: PackedStringArray = []
    var cost: Dictionary = recipe.get("cost", {})
    if !cost.is_empty():
        var keys = cost.keys()
        keys.sort()
        for key in keys:
            var amount = int(cost.get(key, 0))
            if amount <= 0:
                continue
            var label = _resolve_material_label(String(key))
            var stock = inventory_system.get_item_count(key) if inventory_system else 0
            entries.append("%s x%d (Have %d)" % [label, amount, max(stock, 0)])
    var hours = float(recipe.get("hours", 1.0))
    if hours > 0.0:
        var minutes = int(ceil(hours * 60.0 * max(_resolve_multiplier(), 0.01)))
        entries.append("%s build" % _format_duration(minutes))
    var rest_cost = float(recipe.get("rest_cost_percent", 0.0))
    if rest_cost > 0.0:
        entries.append("-%d%% rest" % int(round(rest_cost)))
    entries.append("+%d cal burn" % int(round(GameManager.CRAFT_CALORIE_COST)))

    var lines: PackedStringArray = []
    lines.append("Cost")
    if entries.is_empty():
        lines.append("• None")
    else:
        for entry in entries:
            lines.append("• %s" % entry)
    return "\n".join(lines)

func _format_duration(minutes: int) -> String:
    var hrs = minutes / 60
    var mins = minutes % 60
    if hrs > 0 and mins > 0:
        return "%d hr %d min" % [hrs, mins]
    if hrs > 0:
        return "%d hr" % hrs
    return "%d min" % minutes

func _format_daybreak_warning(minutes_available: int) -> String:
    if minutes_available <= 0:
        return "No time left before 6:00"
    return "Need %s before dawn" % _format_duration(minutes_available)

func _resolve_multiplier() -> float:
    if game_manager == null:
        return 1.0
    return game_manager.get_combined_activity_multiplier()

func _on_inventory_changed(_item_id: String, _quantity: int, _food_delta: float, _total_food: float):
    _update_recipe_states()
    _refresh_detail_text()

func _has_materials_for_recipe(recipe: Dictionary) -> bool:
    var cost: Dictionary = recipe.get("cost", {})
    if cost.is_empty():
        return true
    if inventory_system == null:
        return false
    for key in cost.keys():
        var needed = int(cost.get(key, 0))
        if needed <= 0:
            continue
        if inventory_system.get_item_count(key) < needed:
            return false
    return true

func _resolve_material_label(item_id: String, fallback: String = "") -> String:
    if !fallback.is_empty():
        return fallback
    if inventory_system:
        return inventory_system.get_item_display_name(item_id)
    if item_id.is_empty():
        return "Material"
    return item_id.capitalize()

func _apply_theme_overrides():
    if panel:
        var backdrop := StyleBoxFlat.new()
        backdrop.bg_color = Color(0.08, 0.08, 0.08, 1.0)
        backdrop.set_corner_radius_all(8)
        backdrop.set_border_width_all(2)
        backdrop.border_color = Color(0.3, 0.3, 0.3, 1.0)
        panel.add_theme_stylebox_override("panel", backdrop)
    if title_label:
        title_label.text = "Workshop Planner"
        title_label.add_theme_color_override("font_color", Color.WHITE)
    if recipe_header:
        recipe_header.text = "Blueprints"
        recipe_header.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
    if detail_label:
        detail_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
        detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    if detail_header:
        detail_header.text = "Build Details"
        detail_header.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
    if status_label:
        status_label.add_theme_color_override("font_color", Color.WHITE)
    if button_row:
        button_row.alignment = BoxContainer.ALIGNMENT_END
    if close_button:
        close_button.text = "Close"
        close_button.add_theme_color_override("font_color", Color.WHITE)

func _update_recipe_header():
    if recipe_header == null:
        return
    var count := _recipes.size()
    if count <= 0:
        recipe_header.text = "Blueprints"
    else:
        recipe_header.text = "Blueprints (%d)" % count
