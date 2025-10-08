extends Control

@export var max_sleep_hours: int = 12
@export var forging_results_panel_path: NodePath

const SLEEP_PERCENT_PER_HOUR: int = 10
const SleepSystem = preload("res://scripts/systems/SleepSystem.gd")
const TimeSystem = preload("res://scripts/systems/TimeSystem.gd")
const InventorySystem = preload("res://scripts/systems/InventorySystem.gd")
const TowerHealthSystem = preload("res://scripts/systems/TowerHealthSystem.gd")
const ZombieSystem = preload("res://scripts/systems/ZombieSystem.gd")
const ForgingResultsPanel = preload("res://scripts/ui/ForgingResultsPanel.gd")

const CALORIES_PER_FOOD_UNIT: float = 1000.0
const LEAD_AWAY_CHANCE_PERCENT: int = int(round(ZombieSystem.DEFAULT_LEAD_AWAY_CHANCE * 100.0))

const MEAL_OPTIONS := [
    {
        "key": "small",
        "label": "Small (0.5)",
        "display": "Small",
        "food_units": 0.5
    },
    {
        "key": "normal",
        "label": "Normal (1.0)",
        "display": "Normal",
        "food_units": 1.0
    },
    {
        "key": "large",
        "label": "Large (1.5)",
        "display": "Large",
        "food_units": 1.5
    }
]

var selected_hours: int = 0
var time_system: TimeSystem

var _cached_minutes_remaining: int = 0
var _menu_open: bool = false
var inventory_system: InventorySystem
var tower_health_system: TowerHealthSystem
var zombie_system: ZombieSystem
var selected_meal_key: String = "normal"
var _forging_feedback_state: String = "ready"
var _forging_feedback_locked: bool = false
var _lead_feedback_state: String = "status"
var _lead_feedback_locked: bool = false

@onready var game_manager: GameManager = _resolve_game_manager()
@onready var hours_value_label: Label = $Layout/ActionsPanel/Margin/ActionList/SleepRow/HourSelector/HoursValue
@onready var summary_label: Label = $Layout/DescriptionPanel/Margin/DescriptionList/SummaryLabel
@onready var forging_result_label: Label = $Layout/ActionsPanel/Margin/ActionList/ForgingRow/ForgingResult
@onready var meal_size_option: OptionButton = $Layout/ActionsPanel/Margin/ActionList/MealRow/MealSizeOption
@onready var meal_summary_label: Label = $Layout/ActionsPanel/Margin/ActionList/MealRow/MealSummary
@onready var meal_result_label: Label = $Layout/ActionsPanel/Margin/ActionList/MealResult
@onready var repair_summary_label: Label = $Layout/ActionsPanel/Margin/ActionList/RepairRow/RepairSummary
@onready var repair_result_label: Label = $Layout/ActionsPanel/Margin/ActionList/RepairResult
@onready var lead_result_label: Label = $Layout/ActionsPanel/Margin/ActionList/LeadRow/LeadAwayResult
@onready var description_title_label: Label = $Layout/DescriptionPanel/Margin/DescriptionList/DescriptionTitle
@onready var description_hint_label: Label = $Layout/DescriptionPanel/Margin/DescriptionList/DescriptionHint
@onready var forging_results_panel: ForgingResultsPanel = get_node_or_null(forging_results_panel_path) if forging_results_panel_path != NodePath("") else null

const DESCRIPTION_DEFAULT := {
    "title": "Task Details",
    "hint": "Hover or focus an action to see its requirements."
}

const TASK_DESCRIPTION_META := {
    "sleep": {
        "title": "Rest",
        "hint": "Spend time to recover rest and calories."
    },
    "forging": {
        "title": "Forge",
        "hint": "Search the forest for supplies."
    },
    "lead": {
        "title": "Lead Away",
        "hint": "Draw undead from the tower."
    },
    "meal": {
        "title": "Eat",
        "hint": "Convert stored food into calories."
    },
    "repair": {
        "title": "Repair",
        "hint": "Spend wood to restore tower health."
    }
}

var _current_description: String = "sleep"

func _ready():
    set_process_unhandled_input(true)
    _close_menu()

    if is_instance_valid(description_title_label):
        description_title_label.text = DESCRIPTION_DEFAULT.get("title", "Task Details")
    if is_instance_valid(description_hint_label):
        description_hint_label.text = DESCRIPTION_DEFAULT.get("hint", "Hover an action to see more.")

    if game_manager:
        time_system = game_manager.get_time_system()
        inventory_system = game_manager.get_inventory_system()
        tower_health_system = game_manager.get_tower_health_system()
        if time_system:
            time_system.time_advanced.connect(_on_time_system_changed)
            time_system.day_rolled_over.connect(_on_time_system_changed)
        if inventory_system:
            inventory_system.food_total_changed.connect(_on_inventory_food_total_changed)
            _set_forging_feedback(_format_forging_ready(inventory_system.get_total_food_units()), "ready")
        else:
            _set_forging_feedback("Forging offline", "offline")
        if tower_health_system:
            tower_health_system.tower_health_changed.connect(_on_tower_health_changed)
        zombie_system = game_manager.get_zombie_system()
        if zombie_system:
            zombie_system.zombies_changed.connect(_on_lead_zombie_count_changed)
            _set_lead_feedback(_format_lead_ready(zombie_system.get_active_zombies()), "status")
        else:
            _set_lead_feedback("Lead Away offline", "offline")
    else:
        _set_forging_feedback("Forging unavailable", "offline")
        _set_lead_feedback("Lead Away unavailable", "offline")

    _setup_meal_size_options()
    _setup_description_targets()
    _set_description("sleep", true)
    _refresh_display()

    if forging_results_panel == null:
        var tree = get_tree()
        if tree:
            var root = tree.get_root()
            if root:
                var candidate: Node = root.get_node_or_null("Main/UI/ForgingResultsPanel")
                if candidate is ForgingResultsPanel:
                    forging_results_panel = candidate

func _input(event):
    if event.is_action_pressed("action_menu") and !event.is_echo():
        if visible:
            _close_menu()
        else:
            _open_menu()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("ui_cancel") and visible and !event.is_echo():
        _close_menu()
        get_viewport().set_input_as_handled()

func _refresh_display():
    _cached_minutes_remaining = _get_minutes_left_today()
    var multiplier = game_manager.get_time_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var max_hours_today = min(max_sleep_hours, int(floor(_cached_minutes_remaining / (60.0 * multiplier))))
    if selected_hours > max_hours_today:
        selected_hours = max(max_hours_today, 0)
    hours_value_label.text = str(selected_hours)
    var minutes_remaining = _get_minutes_left_today()
    max_hours_today = min(max_sleep_hours, int(floor(minutes_remaining / (60.0 * multiplier))))
    if selected_hours > max_hours_today:
        selected_hours = max(max_hours_today, 0)
        hours_value_label.text = str(selected_hours)

    _update_meal_summary()
    _update_repair_summary()
    _update_description_body()

func _setup_description_targets():
    var paths := {
        "sleep": [
            "Layout/ActionsPanel/Margin/ActionList/SleepRow",
            "Layout/ActionsPanel/Margin/ActionList/SleepRow/SleepLabel",
            "Layout/ActionsPanel/Margin/ActionList/SleepRow/HourSelector",
            "Layout/ActionsPanel/Margin/ActionList/SleepRow/HourSelector/DecreaseButton",
            "Layout/ActionsPanel/Margin/ActionList/SleepRow/HourSelector/IncreaseButton",
            "Layout/ActionsPanel/Margin/ActionList/SleepRow/SleepButton"
        ],
        "forging": [
            "Layout/ActionsPanel/Margin/ActionList/ForgingRow",
            "Layout/ActionsPanel/Margin/ActionList/ForgingRow/ForgingButton",
            "Layout/ActionsPanel/Margin/ActionList/ForgingRow/ForgingResult"
        ],
        "lead": [
            "Layout/ActionsPanel/Margin/ActionList/LeadRow",
            "Layout/ActionsPanel/Margin/ActionList/LeadRow/LeadAwayButton",
            "Layout/ActionsPanel/Margin/ActionList/LeadRow/LeadAwayResult"
        ],
        "meal": [
            "Layout/ActionsPanel/Margin/ActionList/MealRow",
            "Layout/ActionsPanel/Margin/ActionList/MealRow/MealSizeOption",
            "Layout/ActionsPanel/Margin/ActionList/MealRow/EatButton",
            "Layout/ActionsPanel/Margin/ActionList/MealRow/MealSummary",
            "Layout/ActionsPanel/Margin/ActionList/MealResult"
        ],
        "repair": [
            "Layout/ActionsPanel/Margin/ActionList/RepairRow",
            "Layout/ActionsPanel/Margin/ActionList/RepairRow/RepairButton",
            "Layout/ActionsPanel/Margin/ActionList/RepairRow/RepairSummary",
            "Layout/ActionsPanel/Margin/ActionList/RepairResult"
        ]
    }

    for key in paths.keys():
        for path in paths[key]:
            var node = get_node_or_null(path)
            if node and node is Control:
                _register_description_target(node, key)

func _register_description_target(control: Control, key: String):
    if control == null:
        return
    if control.has_signal("mouse_entered"):
        control.mouse_entered.connect(func(): _set_description(key))
    if control.has_signal("focus_entered"):
        control.focus_entered.connect(func(): _set_description(key))

func _set_description(key: String, force: bool = false):
    if key.is_empty():
        key = _current_description
    if !TASK_DESCRIPTION_META.has(key):
        key = "sleep"
    var changed = key != _current_description
    _current_description = key
    var meta = TASK_DESCRIPTION_META.get(key, DESCRIPTION_DEFAULT)
    if changed or force:
        if is_instance_valid(description_title_label):
            description_title_label.text = meta.get("title", DESCRIPTION_DEFAULT.get("title", "Task Details"))
        if is_instance_valid(description_hint_label):
            description_hint_label.text = meta.get("hint", DESCRIPTION_DEFAULT.get("hint", "Hover or focus an action to see its requirements."))
    _update_description_body()

func _update_description_body():
    if !is_instance_valid(summary_label):
        return
    summary_label.text = _get_description_body(_current_description)

func _get_description_body(key: String) -> String:
    match key:
        "sleep":
            return _build_sleep_description()
        "forging":
            return _build_forging_description()
        "lead":
            return _build_lead_description()
        "meal":
            return _build_meal_description()
        "repair":
            return _build_repair_description()
        _:
            return "Select an action to learn more."

func _build_sleep_description() -> String:
    var lines: PackedStringArray = []
    lines.append("Each hour: +%d%% rest / -%d cal" % [SLEEP_PERCENT_PER_HOUR, SleepSystem.CALORIES_PER_SLEEP_HOUR])
    var multiplier = game_manager.get_time_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes_remaining = _get_minutes_left_today()
    if selected_hours > 0:
        var rest_gain = selected_hours * SLEEP_PERCENT_PER_HOUR
        var calories = selected_hours * SleepSystem.CALORIES_PER_SLEEP_HOUR
        var preview_minutes = int(ceil(selected_hours * 60.0 * multiplier))
        lines.append("%d hr -> +%d%% / -%d cal" % [selected_hours, rest_gain, calories])
        lines.append("Uses %s (x%.1f)" % [_format_duration(preview_minutes), multiplier])
        if time_system and minutes_remaining > 0 and preview_minutes <= minutes_remaining:
            lines.append("Ends at %s" % time_system.get_formatted_time_after(preview_minutes))
    else:
        if minutes_remaining > 0:
            var fractional_hours = minutes_remaining / (60.0 * multiplier)
            var rest_gain_partial = fractional_hours * SLEEP_PERCENT_PER_HOUR
            var calories_partial = fractional_hours * SleepSystem.CALORIES_PER_SLEEP_HOUR
            lines.append("Rest to 6:00 -> +%s%% / -%d cal" % [_format_percent_value(rest_gain_partial), int(round(calories_partial))])
            lines.append("Uses %s (%.2f hr @ x%.1f)" % [_format_duration(minutes_remaining), fractional_hours, multiplier])
        else:
            lines.append("No time left before 6:00 AM.")
    lines.append("Day left: %s" % _format_duration(minutes_remaining))
    return "\n".join(lines)

func _build_forging_description() -> String:
    var lines: PackedStringArray = []
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes = int(ceil(60.0 * multiplier))
    lines.append("Spend 1 hr (x%.1f) to search the woods." % multiplier)
    lines.append("Costs 15%% rest | Loot: 25%% 🍄 / 25%% 🍓 / 25%% 🌰 / 20%% 🐛 / 20%% 🪵 / 15%% 🩹 / 17.5%% 🌿")
    lines.append("Takes %s" % _format_duration(minutes))
    if zombie_system and zombie_system.has_active_zombies():
        lines.append("Blocked: %d undead nearby" % zombie_system.get_active_zombies())
    else:
        lines.append("Ready while the area is clear")
    return "\n".join(lines)

func _build_lead_description() -> String:
    var lines: PackedStringArray = []
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes = int(ceil(60.0 * multiplier))
    lines.append("Spend 1 hr (x%.1f) guiding undead away." % multiplier)
    lines.append("Costs 15%% rest | %d%% success per 🧟" % LEAD_AWAY_CHANCE_PERCENT)
    lines.append("Takes %s" % _format_duration(minutes))
    if zombie_system:
        var count = zombie_system.get_active_zombies()
        if count > 0:
            lines.append("Active undead: %d" % count)
        else:
            lines.append("Needs at least 1 undead present")
    return "\n".join(lines)

func _build_meal_description() -> String:
    var lines: PackedStringArray = []
    var option = _resolve_meal_option(selected_meal_key)
    var food_units = option.get("food_units", 1.0)
    var calories = int(round(food_units * CALORIES_PER_FOOD_UNIT))
    lines.append("Spend 1 hr to eat a %s meal." % option.get("display", selected_meal_key.capitalize()))
    lines.append("Consumes %s food (-%d cal debt)" % [_format_food(food_units), calories])
    if inventory_system:
        lines.append("Food on hand: %s" % _format_food(inventory_system.get_total_food_units()))
    else:
        lines.append("Inventory offline")
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes = int(ceil(60.0 * multiplier))
    lines.append("Takes %s" % _format_duration(minutes))
    return "\n".join(lines)

func _build_repair_description() -> String:
    var lines: PackedStringArray = []
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes = int(ceil(60.0 * multiplier))
    lines.append("Spend 1 hr (x%.1f) restoring the tower." % multiplier)
    lines.append("Costs 10%% rest / -350 cal")
    lines.append("Restores +%s hp" % _format_health_value(TowerHealthSystem.REPAIR_HEALTH_PER_ACTION))
    if inventory_system:
        var wood_stock = inventory_system.get_item_count("wood")
        lines.append("Needs 1 wood (Stock %d)" % wood_stock)
    else:
        lines.append("Needs 1 wood")
    if tower_health_system:
        lines.append("Tower %s" % _format_health_snapshot(tower_health_system.get_health()))
    else:
        lines.append("Tower status offline")
    lines.append("Takes %s" % _format_duration(minutes))
    return "\n".join(lines)
func _on_decrease_button_pressed():
    selected_hours = max(selected_hours - 1, 0)
    _refresh_display()

func _on_increase_button_pressed():
    var multiplier = game_manager.get_time_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var hours_available = min(max_sleep_hours, int(floor(_get_minutes_left_today() / (60.0 * multiplier))))
    if selected_hours >= hours_available:
        print("⚠️ Cannot schedule beyond remaining daily time")
        return
    selected_hours = min(selected_hours + 1, hours_available)
    _refresh_display()

func _on_sleep_button_pressed():
    if game_manager == null:
        return

    var multiplier = game_manager.get_time_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var hours_requested = float(selected_hours)
    var minutes_remaining = _get_minutes_left_today()

    if hours_requested <= 0.0:
        if minutes_remaining <= 0:
            _set_description("sleep", true)
            summary_label.text = "%s\n\nNo time left before 6:00 AM." % _build_sleep_description()
            return
        hours_requested = minutes_remaining / (60.0 * multiplier)

    var result = game_manager.schedule_sleep(hours_requested)
    if result.get("accepted", false):
        print("✅ Sleep applied: %s" % result)
        selected_hours = 0
        _refresh_display()
        _close_menu()
    else:
        var minutes_left = result.get("minutes_available", _get_minutes_left_today())
        var rejection_multiplier = result.get("time_multiplier", multiplier)
        var message = "Not enough time (x%.1f, left: %s)" % [rejection_multiplier, _format_duration(minutes_left)]
        _set_description("sleep", true)
        summary_label.text = "%s\n\n%s" % [_build_sleep_description(), message]
        print("⚠️ Sleep rejected: %s" % result)

func _on_forging_button_pressed():
    if game_manager == null:
        _set_forging_feedback("Forging unavailable", "offline")
        return

    _lock_forging_feedback()
    var result = game_manager.perform_forging()
    _set_forging_feedback(_format_forging_result(result), "result")
    if forging_results_panel:
        forging_results_panel.show_result(result)
    _refresh_display()

func _on_lead_away_button_pressed():
    if game_manager == null:
        _set_lead_feedback("Lead Away unavailable", "offline")
        return

    _lock_lead_feedback()
    var result = game_manager.perform_lead_away_undead()
    _set_lead_feedback(_format_lead_result(result), "result")
    _refresh_display()

func _on_meal_size_option_item_selected(index: int):
    if index < 0 or index >= meal_size_option.item_count:
        return
    var key = meal_size_option.get_item_metadata(index)
    if key is String:
        selected_meal_key = key
    _update_meal_summary()

func _on_eat_button_pressed():
    if game_manager == null:
        meal_result_label.text = "Eating unavailable"
        return

    var result = game_manager.perform_eating(selected_meal_key)
    if !result.get("success", false):
        var reason = result.get("reason", "failed")
        match reason:
            "insufficient_food":
                var required = result.get("required_food", 0.0)
                var available = result.get("total_food_units", 0.0)
                meal_result_label.text = "Need %s food (Have %s)" % [_format_food(required), _format_food(available)]
            "exceeds_day":
                var minutes_available = result.get("minutes_available", 0)
                meal_result_label.text = _format_daybreak_warning(minutes_available)
            _:
                meal_result_label.text = "Meal failed"
        return

    var calories = int(round(result.get("calories_consumed", 0.0)))
    var food_spent = result.get("food_units_spent", 0.0)
    var ended_at = result.get("ended_at_time", "")
    var message_parts: PackedStringArray = []
    message_parts.append("-%d cal" % calories)
    message_parts.append("-%s food" % _format_food(food_spent))
    if ended_at != "":
        message_parts.append("End %s" % ended_at)
    meal_result_label.text = "%s meal -> %s" % [result.get("portion", selected_meal_key).capitalize(), " | ".join(message_parts)]
    _refresh_display()

func _on_repair_button_pressed():
    if game_manager == null:
        repair_result_label.text = "Repair unavailable"
        return

    var result = game_manager.repair_tower({})
    if !result.get("success", false):
        var reason = result.get("reason", "failed")
        match reason:
            "tower_full_health":
                repair_result_label.text = "Tower already stable"
            "exceeds_day":
                var minutes_available = result.get("minutes_available", 0)
                repair_result_label.text = _format_daybreak_warning(minutes_available)
            "insufficient_wood":
                var required = int(result.get("wood_required", 1))
                var available = int(result.get("wood_available", 0))
                repair_result_label.text = "Need %d wood (Have %d)" % [required, available]
            _:
                repair_result_label.text = "Repair failed"
        return

    var restored = result.get("health_restored", 0.0)
    var after = result.get("health_after", 0.0)
    var ended_at = result.get("ended_at_time", "")
    var parts: PackedStringArray = []
    parts.append("+%s hp" % _format_health_value(restored))
    parts.append("%s" % _format_health_snapshot(after))
    parts.append("-%d cal" % int(round(result.get("calories_spent", 0.0))))
    var wood_spent = int(result.get("wood_spent", 0))
    if wood_spent > 0:
        parts.append("-%d wood (Stock %d)" % [wood_spent, int(result.get("wood_remaining", 0))])
    var rest_bonus = result.get("rest_granted_percent", 0.0)
    if rest_bonus > 0.0:
        parts.append("+%d%% rest" % int(round(rest_bonus)))
    if ended_at != "":
        parts.append("End %s" % ended_at)
    repair_result_label.text = "Repair -> %s" % " | ".join(parts)
    _refresh_display()

func _format_forging_ready(total_food: float) -> String:
    return "Forging ready (-15% rest | Food %.1f)" % total_food

func _format_forging_result(result: Dictionary) -> String:
    var end_at = result.get("ended_at_time", "")
    if result.get("success", false):
        var parts: PackedStringArray = []
        var loot: Array = result.get("loot", [])
        if loot.is_empty():
            parts.append("Supplies added")
        else:
            for item in loot:
                var label = item.get("display_name", item.get("item_id", "Find"))
                var qty = int(item.get("quantity_added", item.get("quantity", 1)))
                var entry = "%s x%d" % [label, max(qty, 1)]
                var food_gain = float(item.get("food_gained", 0.0))
                if !is_zero_approx(food_gain):
                    entry += " (+%s food)" % _format_food(food_gain)
                parts.append(entry)
        parts.append("Total %s" % _format_food(result.get("total_food_units", 0.0)))
        var rest_spent = result.get("rest_spent_percent", 0.0)
        if rest_spent > 0.0:
            parts.append("-%d%% rest" % int(round(rest_spent)))
        if end_at != "":
            parts.append("End %s" % end_at)
        return " | ".join(parts)

    var reason = result.get("reason", "")
    match reason:
        "systems_unavailable":
            return "Forging offline"
        "zombies_present":
            var count = int(result.get("zombie_count", 0))
            return "Zombies nearby! Forging blocked (%d)" % max(count, 1)
        "nothing_found":
            var message = "Found nothing"
            var rest_spent = result.get("rest_spent_percent", 0.0)
            if rest_spent > 0.0:
                message += " | -%d%% rest" % int(round(rest_spent))
            if end_at != "":
                message += " | End %s" % end_at
            return message
        "exceeds_day":
            var minutes_available = result.get("minutes_available", 0)
            return _format_daybreak_warning(minutes_available)
        _:
            var fallback = "Forging failed"
            var rest_spent = result.get("rest_spent_percent", 0.0)
            if rest_spent > 0.0:
                fallback += " | -%d%% rest" % int(round(rest_spent))
            return fallback

func _get_minutes_left_today() -> int:
    if time_system:
        return time_system.get_minutes_until_daybreak()
    return max_sleep_hours * 60

func _on_time_system_changed(_a = null, _b = null):
    _refresh_display()

func _format_duration(minutes: int) -> String:
    minutes = max(minutes, 0)
    var hours = minutes / 60
    var mins = minutes % 60
    if hours > 0 and mins > 0:
        return "%dh %02dm" % [hours, mins]
    elif hours > 0:
        return "%dh" % hours
    else:
        return "%dm" % mins

func _format_daybreak_warning(minutes_available: int) -> String:
    return "Daybreak soon (Left %s)" % _format_duration(minutes_available)

func _set_forging_feedback(text: String, state: String):
    if !is_instance_valid(forging_result_label):
        return
    forging_result_label.text = text
    _forging_feedback_state = state

func _lock_forging_feedback():
    _forging_feedback_locked = true
    call_deferred("_unlock_forging_feedback")

func _unlock_forging_feedback():
    _forging_feedback_locked = false

func _set_lead_feedback(text: String, state: String):
    if !is_instance_valid(lead_result_label):
        return
    lead_result_label.text = text
    _lead_feedback_state = state

func _lock_lead_feedback():
    _lead_feedback_locked = true
    call_deferred("_unlock_lead_feedback")

func _unlock_lead_feedback():
    _lead_feedback_locked = false

func _open_menu():
    if _menu_open:
        return
    _menu_open = true
    _refresh_display()
    visible = true

func _close_menu():
    if !_menu_open and !visible:
        return
    _menu_open = false
    visible = false

func _setup_meal_size_options():
    if !is_instance_valid(meal_size_option):
        return
    meal_size_option.clear()
    for option in MEAL_OPTIONS:
        var idx = meal_size_option.item_count
        meal_size_option.add_item(option.get("label", option.get("display", "Meal")))
        meal_size_option.set_item_metadata(idx, option.get("key", "normal"))
        if option.get("key", "normal") == selected_meal_key:
            meal_size_option.select(idx)
    if meal_size_option.selected == -1 and meal_size_option.item_count > 0:
        meal_size_option.select(0)
        selected_meal_key = meal_size_option.get_item_metadata(0)
    _update_meal_summary()

func _update_meal_summary():
    if !is_instance_valid(meal_summary_label):
        return
    var option = _resolve_meal_option(selected_meal_key)
    var food_units = option.get("food_units", 1.0)
    var calories = int(round(food_units * CALORIES_PER_FOOD_UNIT))
    var lines: PackedStringArray = []
    lines.append("%s meal -> -%s food / -%d cal" % [option.get("display", selected_meal_key.capitalize()), _format_food(food_units), calories])
    if inventory_system:
        lines.append("Stock: %s food" % _format_food(inventory_system.get_total_food_units()))
    else:
        lines.append("Inventory offline")
    meal_summary_label.text = "\n".join(lines)

func _update_repair_summary():
    if !is_instance_valid(repair_summary_label):
        return
    var lines: PackedStringArray = []
    lines.append("Repair -> +%s hp" % _format_health_value(TowerHealthSystem.REPAIR_HEALTH_PER_ACTION))
    lines.append("+10% rest / -350 cal")
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    var minutes = int(ceil(60.0 * max(multiplier, 0.01)))
    lines.append("Takes %s" % _format_duration(minutes))
    if inventory_system:
        var wood_stock = inventory_system.get_item_count("wood")
        lines.append("Needs 1 wood (Stock %d)" % wood_stock)
    else:
        lines.append("Needs 1 wood")
    if tower_health_system:
        lines.append("Tower %s" % _format_health_snapshot(tower_health_system.get_health()))
    repair_summary_label.text = " | ".join(lines)

func _resolve_meal_option(key: String) -> Dictionary:
    var normalized = key.to_lower()
    for option in MEAL_OPTIONS:
        if option.get("key", "") == normalized:
            return option
    return MEAL_OPTIONS[1]

func _format_food(value: float) -> String:
    if is_equal_approx(value, round(value)):
        return "%d" % int(round(value))
    return "%.1f" % value

func _format_percent_value(value: float) -> String:
    var rounded = round(value * 10.0) / 10.0
    if is_equal_approx(rounded, round(rounded)):
        return "%d" % int(round(rounded))
    return "%.1f" % rounded

func _format_lead_ready(count: int) -> String:
    return "Lead Away -> %d%% per 🧟 (Have %d)" % [LEAD_AWAY_CHANCE_PERCENT, max(count, 0)]

func _format_lead_result(result: Dictionary) -> String:
    var rest_spent = result.get("rest_spent_percent", 0.0)
    var ended_at = result.get("ended_at_time", "")
    if result.get("success", false):
        var removed = int(result.get("removed", 0))
        var remaining = int(result.get("remaining", 0))
        var chance = float(result.get("chance", 0.0)) * 100.0
        var parts: PackedStringArray = []
        parts.append("Removed %d" % max(removed, 0))
        parts.append("Remain %d" % max(remaining, 0))
        parts.append("%.0f%% each" % chance)
        if rest_spent > 0.0:
            parts.append("-%d%% rest" % int(round(rest_spent)))
        if ended_at != "":
            parts.append("End %s" % ended_at)
        return "Lead Away -> %s" % " | ".join(parts)

    var reason = result.get("reason", "")
    match reason:
        "systems_unavailable":
            return "Lead Away offline"
        "no_zombies":
            return "No zombies nearby"
        "exceeds_day":
            var minutes_available = result.get("minutes_available", 0)
            return _format_daybreak_warning(minutes_available)
        "zombies_stayed":
            var rolls = int(result.get("rolls", 0))
            var chance = float(result.get("chance", 0.0)) * 100.0
            var fragments: PackedStringArray = []
            fragments.append("No takers (%d @ %.0f%%)" % [max(rolls, 0), chance])
            if rest_spent > 0.0:
                fragments.append("-%d%% rest" % int(round(rest_spent)))
            if ended_at != "":
                fragments.append("End %s" % ended_at)
            return "Lead Away -> %s" % " | ".join(fragments)
        _:
            var fallback = "Lead Away failed"
            if rest_spent > 0.0:
                fallback += " | -%d%% rest" % int(round(rest_spent))
            if ended_at != "":
                fallback += " | End %s" % ended_at
            return fallback

func _format_health_value(value: float) -> String:
    if is_zero_approx(value - round(value)):
        return "%d" % int(round(value))
    return "%.1f" % value

func _format_health_snapshot(value: float) -> String:
    if tower_health_system == null:
        return "--"
    return "%s/%s" % [_format_health_value(value), _format_health_value(tower_health_system.get_max_health())]

func _on_inventory_food_total_changed(new_total: float):
    _update_meal_summary()
    if _forging_feedback_locked:
        return
    if _forging_feedback_state == "offline":
        return
    _set_forging_feedback(_format_forging_ready(new_total), "ready")

func _on_tower_health_changed(_new: float, _old: float):
    _update_repair_summary()

func _on_lead_zombie_count_changed(count: int):
    if _lead_feedback_locked:
        return
    if _lead_feedback_state == "offline":
        return
    _set_lead_feedback(_format_lead_ready(count), "status")

func _resolve_game_manager() -> GameManager:
    var tree = get_tree()
    if tree == null:
        push_warning("SceneTree unavailable, cannot resolve GameManager")
        return null

    var root = tree.get_root()
    if root == null:
        push_warning("Root node unavailable, cannot resolve GameManager")
        return null

    var candidate: Node = root.get_node_or_null("Main/GameManager")
    if candidate == null:
        var group_matches = tree.get_nodes_in_group("game_manager") if tree.has_group("game_manager") else []
        if group_matches.size() > 0:
            candidate = group_matches[0]

    if candidate is GameManager:
        return candidate

    if candidate:
        push_warning("GameManager node found but type mismatch: %s" % candidate.name)
    else:
        push_warning("GameManager node not found in scene tree")

    return null
