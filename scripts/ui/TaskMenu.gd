# TaskMenu.gd overview:
# - Purpose: queue survivor tasks (sleep, meals, repairs, forging, lead-away) and feed results back to systems.
# - Sections: exports tune UI ranges, preloads cache systems, onready grabs controls, handlers manage actions and feedback text.
extends Control

# Maximum hours the player can queue for sleep (keep within 4 - 16 for balance).
@export var max_sleep_hours: int = 12
@export var forging_results_panel_path: NodePath

const SLEEP_PERCENT_PER_HOUR: int = 10
const SleepSystem = preload("res://scripts/systems/SleepSystem.gd")
const TimeSystem = preload("res://scripts/systems/TimeSystem.gd")
const WeatherSystem = preload("res://scripts/systems/WeatherSystem.gd")
const InventorySystem = preload("res://scripts/systems/InventorySystem.gd")
const TowerHealthSystem = preload("res://scripts/systems/TowerHealthSystem.gd")
const ZombieSystem = preload("res://scripts/systems/ZombieSystem.gd")
const ForgingResultsPanel = preload("res://scripts/ui/ForgingResultsPanel.gd")

const CALORIES_PER_FOOD_UNIT: float = 1000.0
const LEAD_AWAY_CHANCE_PERCENT: int = int(round(ZombieSystem.DEFAULT_LEAD_AWAY_CHANCE * 100.0))
const RECON_OUTLOOK_HOURS: int = 6

# Meal presets surfaced to the menu; food_units mirror GameManager expectations.
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
var weather_system: WeatherSystem
var selected_meal_key: String = "normal"
var _forging_feedback_state: String = "ready"
var _forging_feedback_locked: bool = false
var _lead_feedback_state: String = "status"
var _lead_feedback_locked: bool = false

var _selected_action: String = "sleep"
var _action_status_text: Dictionary = {}
var _action_defaults: Dictionary = {}
var _action_results_active: Dictionary = {}
var _action_buttons: Dictionary = {}

# Grab nodes and buttons once so focus behavior remains consistent.
@onready var game_manager: GameManager = _resolve_game_manager()
@onready var hours_value_label: Label = $Layout/ActionsPanel/Margin/ActionList/SleepRow/HourSelector/HoursValue
@onready var info_title_label: Label = $Layout/InfoPanel/InfoMargin/InfoList/DescriptionTitle
@onready var info_body_label: Label = $Layout/InfoPanel/InfoMargin/InfoList/SummaryLabel
@onready var info_status_label: Label = $Layout/InfoPanel/InfoMargin/InfoList/InfoStatus
@onready var info_hint_label: Label = $Layout/InfoPanel/InfoMargin/InfoList/DescriptionHint
@onready var go_button: Button = $Layout/InfoPanel/InfoMargin/InfoList/GoRow/GoButton
@onready var forging_results_panel: ForgingResultsPanel = get_node_or_null(forging_results_panel_path) if forging_results_panel_path != NodePath("") else null
@onready var meal_size_option: OptionButton = $Layout/ActionsPanel/Margin/ActionList/MealRow/MealSizeOption
@onready var meal_summary_label: Label = $Layout/ActionsPanel/Margin/ActionList/MealRow/MealSummary
@onready var repair_summary_label: Label = $Layout/ActionsPanel/Margin/ActionList/RepairRow/RepairSummary
@onready var forging_status_label: Label = $Layout/ActionsPanel/Margin/ActionList/ForgingRow/ForgingStatus
@onready var lead_status_label: Label = $Layout/ActionsPanel/Margin/ActionList/LeadRow/LeadStatus
@onready var reinforce_summary_label: Label = $Layout/ActionsPanel/Margin/ActionList/ReinforceRow/ReinforceSummary
@onready var sleep_select_button: Button = $Layout/ActionsPanel/Margin/ActionList/SleepRow/SleepSelectButton
@onready var forging_select_button: Button = $Layout/ActionsPanel/Margin/ActionList/ForgingRow/ForgingSelectButton
@onready var recon_status_label: Label = $Layout/ActionsPanel/Margin/ActionList/ReconRow/ReconStatus
@onready var recon_select_button: Button = $Layout/ActionsPanel/Margin/ActionList/ReconRow/ReconSelectButton
@onready var lead_select_button: Button = $Layout/ActionsPanel/Margin/ActionList/LeadRow/LeadSelectButton
@onready var meal_select_button: Button = $Layout/ActionsPanel/Margin/ActionList/MealRow/MealSelectButton
@onready var repair_select_button: Button = $Layout/ActionsPanel/Margin/ActionList/RepairRow/RepairSelectButton
@onready var reinforce_select_button: Button = $Layout/ActionsPanel/Margin/ActionList/ReinforceRow/ReinforceSelectButton

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
    "recon": {
        "title": "Recon",
        "hint": "Scout weather and undead approach windows."
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
    },
    "reinforce": {
        "title": "Reinforce",
        "hint": "Fortify the tower past its base strength."
    }
}

func _ready():
    # Prepare button callbacks and sync default descriptions before showing the menu.
    set_process_input(true)
    set_process_unhandled_input(true)
    _close_menu()

    if is_instance_valid(info_title_label):
        info_title_label.text = DESCRIPTION_DEFAULT.get("title", "Task Details")
    if is_instance_valid(info_hint_label):
        info_hint_label.text = DESCRIPTION_DEFAULT.get("hint", "Hover or focus an action to see its requirements.")
    if is_instance_valid(info_status_label):
        info_status_label.text = ""

    if go_button:
        go_button.pressed.connect(_on_go_button_pressed)

    _register_action_selector(sleep_select_button, "sleep")
    _register_action_selector(forging_select_button, "forging")
    _register_action_selector(recon_select_button, "recon")
    _register_action_selector(lead_select_button, "lead")
    _register_action_selector(meal_select_button, "meal")
    _register_action_selector(repair_select_button, "repair")
    _register_action_selector(reinforce_select_button, "reinforce")

    if game_manager:
        time_system = game_manager.get_time_system()
        inventory_system = game_manager.get_inventory_system()
        tower_health_system = game_manager.get_tower_health_system()
        weather_system = game_manager.get_weather_system()
        if time_system:
            time_system.time_advanced.connect(_on_time_system_changed)
            time_system.day_rolled_over.connect(_on_time_system_changed)
        if inventory_system:
            inventory_system.food_total_changed.connect(_on_inventory_food_total_changed)
            inventory_system.item_added.connect(_on_inventory_item_changed)
            inventory_system.item_consumed.connect(_on_inventory_item_changed)
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
    _select_action("sleep", true)
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
    _handle_menu_input(event)

func _unhandled_input(event):
    _handle_menu_input(event)

func _handle_menu_input(event):
    # Toggle the task overlay or close it with escape-style actions.
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
    # Recalculate limits and UI summaries whenever time, inventory, or selection changes.
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
    _update_recon_summary()
    _update_repair_summary()
    _update_reinforce_summary()
    _update_description_body()
    _update_info_status()

func _setup_description_targets():
    var paths := {
        "sleep": [
            "Layout/ActionsPanel/Margin/ActionList/SleepRow",
            "Layout/ActionsPanel/Margin/ActionList/SleepRow/SleepLabel",
            "Layout/ActionsPanel/Margin/ActionList/SleepRow/HourSelector",
            "Layout/ActionsPanel/Margin/ActionList/SleepRow/HourSelector/DecreaseButton",
            "Layout/ActionsPanel/Margin/ActionList/SleepRow/HourSelector/IncreaseButton",
            "Layout/ActionsPanel/Margin/ActionList/SleepRow/SleepSelectButton"
        ],
        "forging": [
            "Layout/ActionsPanel/Margin/ActionList/ForgingRow",
            "Layout/ActionsPanel/Margin/ActionList/ForgingRow/ForgingStatus",
            "Layout/ActionsPanel/Margin/ActionList/ForgingRow/ForgingSelectButton"
        ],
        "recon": [
            "Layout/ActionsPanel/Margin/ActionList/ReconRow",
            "Layout/ActionsPanel/Margin/ActionList/ReconRow/ReconStatus",
            "Layout/ActionsPanel/Margin/ActionList/ReconRow/ReconSelectButton"
        ],
        "lead": [
            "Layout/ActionsPanel/Margin/ActionList/LeadRow",
            "Layout/ActionsPanel/Margin/ActionList/LeadRow/LeadStatus",
            "Layout/ActionsPanel/Margin/ActionList/LeadRow/LeadSelectButton"
        ],
        "meal": [
            "Layout/ActionsPanel/Margin/ActionList/MealRow",
            "Layout/ActionsPanel/Margin/ActionList/MealRow/MealSizeOption",
            "Layout/ActionsPanel/Margin/ActionList/MealRow/MealSummary",
            "Layout/ActionsPanel/Margin/ActionList/MealRow/MealSelectButton"
        ],
        "repair": [
            "Layout/ActionsPanel/Margin/ActionList/RepairRow",
            "Layout/ActionsPanel/Margin/ActionList/RepairRow/RepairSummary",
            "Layout/ActionsPanel/Margin/ActionList/RepairRow/RepairSelectButton"
        ],
        "reinforce": [
            "Layout/ActionsPanel/Margin/ActionList/ReinforceRow",
            "Layout/ActionsPanel/Margin/ActionList/ReinforceRow/ReinforceSummary",
            "Layout/ActionsPanel/Margin/ActionList/ReinforceRow/ReinforceSelectButton"
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
    _select_action(key, force)

func _update_description_body():
    if !is_instance_valid(info_body_label):
        return
    info_body_label.text = _get_description_body(_selected_action)

func _get_description_body(key: String) -> String:
    match key:
        "sleep":
            return _build_sleep_description()
        "forging":
            return _build_forging_description()
        "recon":
            return _build_recon_description()
        "lead":
            return _build_lead_description()
        "meal":
            return _build_meal_description()
        "repair":
            return _build_repair_description()
        "reinforce":
            return _build_reinforce_description()
        _:
            return "Select an action to learn more."
func _select_action(key: String, force: bool = false):
    if key.is_empty():
        key = _selected_action
    if !TASK_DESCRIPTION_META.has(key):
        key = "sleep"
    var changed = force or key != _selected_action
    _selected_action = key
    var meta = TASK_DESCRIPTION_META.get(key, DESCRIPTION_DEFAULT)
    if is_instance_valid(info_title_label):
        info_title_label.text = meta.get("title", DESCRIPTION_DEFAULT.get("title", "Task Details"))
    if is_instance_valid(info_hint_label):
        info_hint_label.text = meta.get("hint", DESCRIPTION_DEFAULT.get("hint", "Hover or focus an action to see its requirements."))
    _update_description_body()
    _update_info_status()
    if changed or force:
        _update_action_highlights()

func _register_action_selector(button: BaseButton, action: String):
    if button == null:
        return
    button.toggle_mode = true
    button.button_pressed = action == _selected_action
    button.pressed.connect(func():
        _select_action(action)
    )
    _action_buttons[action] = button

func _update_action_highlights():
    for key in _action_buttons.keys():
        var button: BaseButton = _action_buttons[key]
        if button and is_instance_valid(button):
            button.button_pressed = key == _selected_action

func _update_info_status():
    if !is_instance_valid(info_status_label):
        return
    var text = _action_status_text.get(_selected_action, "")
    info_status_label.text = text
    info_status_label.visible = !text.is_empty()

func _set_action_status(action: String, text: String, update_row: bool = false):
    _action_status_text[action] = text
    if update_row:
        match action:
            "forging":
                if is_instance_valid(forging_status_label):
                    forging_status_label.text = text
            "recon":
                if is_instance_valid(recon_status_label):
                    recon_status_label.text = text
            "lead":
                if is_instance_valid(lead_status_label):
                    lead_status_label.text = text
            "meal":
                if is_instance_valid(meal_summary_label):
                    meal_summary_label.text = text
            "repair":
                if is_instance_valid(repair_summary_label):
                    repair_summary_label.text = text
            "reinforce":
                if is_instance_valid(reinforce_summary_label):
                    reinforce_summary_label.text = text
    if action == _selected_action:
        _update_info_status()

func _set_action_default(action: String, text: String, update_row: bool = false):
    _action_defaults[action] = text
    if !_action_results_active.get(action, false):
        _set_action_status(action, text, update_row)

func _set_action_result(action: String, text: String, update_row: bool = false):
    var active = !text.is_empty()
    _action_results_active[action] = active
    if active:
        _set_action_status(action, text, update_row)
    else:
        _set_action_status(action, _action_defaults.get(action, ""), update_row)

func _trigger_selected_action():
    match _selected_action:
        "sleep":
            _execute_sleep_action()
        "forging":
            _execute_forging_action()
        "recon":
            _execute_recon_action()
        "lead":
            _execute_lead_action()
        "meal":
            _execute_meal_action()
        "repair":
            _execute_repair_action()
        "reinforce":
            _execute_reinforce_action()

func _on_go_button_pressed():
    _trigger_selected_action()


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
    lines.append("Costs 15%% rest | Basic: 🍄25%% / 🍓25%% / 🌰25%% / 🐛20%% / 🧵15%% / 🪨30%% / 🌿17.5%% / 🪵20%%")
    lines.append("Advanced finds (10%%): Plastic Sheet, Metal Scrap, Nails x3, Duct Tape, Medicinal Herbs, Fuel (3-5), Mechanical Parts, Electrical Parts")
    lines.append("Takes %s" % _format_duration(minutes))
    if zombie_system and zombie_system.has_active_zombies():
        lines.append("Blocked: %d undead nearby" % zombie_system.get_active_zombies())
    else:
        lines.append("Ready while the area is clear")
    return "\n".join(lines)

func _build_recon_description() -> String:
    var lines: PackedStringArray = []
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes = int(ceil(60.0 * multiplier))
    lines.append("Spend 1 hr (x%.1f) reviewing maps and radio logs." % multiplier)
    lines.append("Costs %d cal | Forecast next %d hr of rain and undead." % [int(round(GameManager.RECON_CALORIE_COST)), RECON_OUTLOOK_HOURS])
    var minutes_remaining = _get_minutes_left_today()
    if time_system and minutes > 0 and minutes <= minutes_remaining:
        lines.append("Ends at %s" % time_system.get_formatted_time_after(minutes))
    var window_minutes = RECON_OUTLOOK_HOURS * 60
    if minutes_remaining <= window_minutes:
        lines.append("Includes dawn check in %s" % _format_duration(minutes_remaining))
    else:
        lines.append("Next dawn beyond outlook (%s)" % _format_duration(window_minutes))
    lines.append("Day left: %s" % _format_duration(minutes_remaining))
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

func _build_reinforce_description() -> String:
    var lines: PackedStringArray = []
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var minutes = int(ceil(120.0 * multiplier))
    lines.append("Spend 2 hr (x%.1f) fortifying the tower." % multiplier)
    lines.append("Costs 20%% rest / -450 cal")
    lines.append("Adds +%s hp (cap %s)" % [
        _format_health_value(25.0),
        _format_health_value(TowerHealthSystem.REINFORCED_MAX_HEALTH)
    ])
    if inventory_system:
        var wood_stock = inventory_system.get_item_count("wood")
        var nails_stock = inventory_system.get_item_count("nails")
        lines.append("Needs 3 wood (Stock %d)" % wood_stock)
        lines.append("Needs 5 nails (Stock %d)" % nails_stock)
    else:
        lines.append("Needs 3 wood & 5 nails")
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

func _execute_sleep_action():
    if game_manager == null:
        _set_action_result("sleep", "Sleep unavailable")
        return

    var multiplier = game_manager.get_time_multiplier() if game_manager else 1.0
    multiplier = max(multiplier, 0.01)
    var hours_requested = float(selected_hours)
    var minutes_remaining = _get_minutes_left_today()

    if hours_requested <= 0.0:
        if minutes_remaining <= 0:
            _select_action("sleep", true)
            _set_action_result("sleep", "No time left before 6:00 AM.")
            return
        hours_requested = minutes_remaining / (60.0 * multiplier)

    var result = game_manager.schedule_sleep(hours_requested)
    if result.get("accepted", false):
        print("✅ Sleep applied: %s" % result)
        selected_hours = 0
        _set_action_result("sleep", "")
        _refresh_display()
        _close_menu()
    else:
        var minutes_left = result.get("minutes_available", _get_minutes_left_today())
        var rejection_multiplier = result.get("time_multiplier", multiplier)
        var message = "Not enough time (x%.1f, left: %s)" % [rejection_multiplier, _format_duration(minutes_left)]
        _select_action("sleep", true)
        _set_action_result("sleep", message)
        print("⚠️ Sleep rejected: %s" % result)

func _execute_forging_action():
    if game_manager == null:
        _set_forging_feedback("Forging unavailable", "offline")
        return

    _lock_forging_feedback()
    var result = game_manager.perform_forging()
    _set_forging_feedback(_format_forging_result(result), "result")
    if forging_results_panel:
        forging_results_panel.show_result(result)
    _refresh_display()

func _execute_lead_action():
    if game_manager == null:
        _set_lead_feedback("Lead Away unavailable", "offline")
        return

    _lock_lead_feedback()
    var result = game_manager.perform_lead_away_undead()
    _set_lead_feedback(_format_lead_result(result), "result")
    _refresh_display()

func _execute_recon_action():
    if game_manager == null:
        _set_action_result("recon", "Recon unavailable", true)
        return

    var result = game_manager.perform_recon()
    if !result.get("success", false):
        var reason = result.get("reason", "failed")
        var message: String
        match reason:
            "systems_unavailable":
                message = "Recon offline"
            "after_window":
                var window_after: Dictionary = result.get("window", {})
                var resume_minutes = int(window_after.get("resumes_in_minutes", 0))
                if resume_minutes > 0:
                    message = "Recon back %s" % _format_duration(resume_minutes)
                else:
                    var resume_label = String(window_after.get("resumes_at", "6:00 AM"))
                    message = "Recon back at %s" % resume_label
            "before_window":
                var window_before: Dictionary = result.get("window", {})
                var wait_minutes = int(window_before.get("minutes_until_window", 0))
                if wait_minutes > 0:
                    message = "Recon ready %s" % _format_duration(wait_minutes)
                else:
                    var resume_clock = String(window_before.get("resumes_at", "6:00 AM"))
                    message = "Recon ready at %s" % resume_clock
            "exceeds_day":
                var minutes_available = result.get("minutes_available", 0)
                message = _format_daybreak_warning(minutes_available)
            "blocked":
                var minutes_available = result.get("minutes_available", 0)
                message = _format_daybreak_warning(minutes_available)
            _:
                message = "Recon failed"
        _set_action_result("recon", message, true)
        return

    var message = _format_recon_result(result)
    _set_action_result("recon", message, true)
    _refresh_display()

func _on_meal_size_option_item_selected(index: int):
    if index < 0 or index >= meal_size_option.item_count:
        return
    var key = meal_size_option.get_item_metadata(index)
    if key is String:
        selected_meal_key = key
    _update_meal_summary()

func _execute_meal_action():
    if game_manager == null:
        _set_action_result("meal", "Eating unavailable")
        return

    var result = game_manager.perform_eating(selected_meal_key)
    if !result.get("success", false):
        var reason = result.get("reason", "failed")
        var message: String
        match reason:
            "insufficient_food":
                var required = result.get("required_food", 0.0)
                var available = result.get("total_food_units", 0.0)
                message = "Need %s food (Have %s)" % [_format_food(required), _format_food(available)]
            "exceeds_day":
                var minutes_available = result.get("minutes_available", 0)
                message = _format_daybreak_warning(minutes_available)
            _:
                message = "Meal failed"
        _set_action_result("meal", message)
        return

    var calories = int(round(result.get("calories_consumed", 0.0)))
    var food_spent = result.get("food_units_spent", 0.0)
    var ended_at = result.get("ended_at_time", "")
    var message_parts: PackedStringArray = []
    message_parts.append("-%d cal" % calories)
    message_parts.append("-%s food" % _format_food(food_spent))
    if ended_at != "":
        message_parts.append("End %s" % ended_at)
    var message = "%s meal -> %s" % [result.get("portion", selected_meal_key).capitalize(), " | ".join(message_parts)]
    _set_action_result("meal", message)
    _refresh_display()

func _execute_repair_action():
    if game_manager == null:
        _set_action_result("repair", "Repair unavailable")
        return

    var result = game_manager.repair_tower({})
    if !result.get("success", false):
        var reason = result.get("reason", "failed")
        var message: String
        match reason:
            "tower_full_health":
                message = "Tower already stable"
            "exceeds_day":
                var minutes_available = result.get("minutes_available", 0)
                message = _format_daybreak_warning(minutes_available)
            "insufficient_wood":
                var required = int(result.get("wood_required", 1))
                var available = int(result.get("wood_available", 0))
                message = "Need %d wood (Have %d)" % [required, available]
            _:
                message = "Repair failed"
        _set_action_result("repair", message)
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
    var message = "Repair -> %s" % " | ".join(parts)
    _set_action_result("repair", message)
    _refresh_display()
func _execute_reinforce_action():
    if game_manager == null:
        _set_action_result("reinforce", "Reinforce unavailable")
        return

    var result = game_manager.reinforce_tower({})
    if !result.get("success", false):
        var reason = result.get("reason", "failed")
        var message: String
        match reason:
            "exceeds_day":
                var minutes_available = result.get("minutes_available", 0)
                message = _format_daybreak_warning(minutes_available)
            "insufficient_material":
                var need: PackedStringArray = []
                var required_wood = int(result.get("wood_required", 3))
                var wood_available = int(result.get("wood_available", 0))
                if wood_available < required_wood:
                    need.append("Need %d wood (Have %d)" % [required_wood, wood_available])
                var required_nails = int(result.get("nails_required", 5))
                var nails_available = int(result.get("nails_available", 0))
                if nails_available < required_nails:
                    need.append("Need %d nails (Have %d)" % [required_nails, nails_available])
                if need.is_empty():
                    need.append("Materials missing")
                message = " / ".join(need)
            "reinforced_cap":
                var cap_value = int(round(result.get("health", TowerHealthSystem.REINFORCED_MAX_HEALTH)))
                message = "Tower fully fortified (%d)" % cap_value
            "tower_full_health":
                var cap = int(round(result.get("health", TowerHealthSystem.REINFORCED_MAX_HEALTH)))
                message = "Tower already fortified (%d)" % cap
            "wood_consume_failed":
                message = "Wood spend failed"
            "nails_consume_failed":
                message = "Nails spend failed"
            "systems_unavailable":
                message = "Systems offline"
            _:
                message = "Reinforce failed"
        _set_action_result("reinforce", message)
        return

    var added = result.get("health_added", 0.0)
    var after = result.get("health_after", 0.0)
    var ended_at = result.get("ended_at_time", "")
    var rest_spent = result.get("rest_spent_percent", 0.0)
    var calories = int(round(result.get("calories_spent", 0.0)))
    var wood_spent = int(result.get("wood_spent", 0))
    var nails_spent = int(result.get("nails_spent", 0))
    var wood_remaining = int(result.get("wood_remaining", 0))
    var nails_remaining = int(result.get("nails_remaining", 0))
    var parts: PackedStringArray = []
    parts.append("+%s hp" % _format_health_value(added))
    parts.append("%s" % _format_health_snapshot(after))
    if rest_spent > 0.0:
        parts.append("-%d%% rest" % int(round(rest_spent)))
    if calories > 0:
        parts.append("-%d cal" % calories)
    if wood_spent > 0:
        var wood_fragment = "-%d wood" % wood_spent
        wood_fragment += " (Stock %d)" % max(wood_remaining, 0)
        parts.append(wood_fragment)
    if nails_spent > 0:
        var nail_fragment = "-%d nails" % nails_spent
        nail_fragment += " (Stock %d)" % max(nails_remaining, 0)
        parts.append(nail_fragment)
    if ended_at != "":
        parts.append("End %s" % ended_at)
    var message = "Reinforce -> %s" % " | ".join(parts)
    _set_action_result("reinforce", message)
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

func _format_recon_result(result: Dictionary) -> String:
    var parts: PackedStringArray = []
    var hours_scanned = int(result.get("hours_scanned", RECON_OUTLOOK_HOURS))
    parts.append("Scouted %dh" % max(hours_scanned, 1))
    var calories = int(round(result.get("calories_spent", GameManager.RECON_CALORIE_COST)))
    if calories > 0:
        parts.append("-%d cal" % calories)
    var ended_at = result.get("ended_at_time", "")
    if ended_at != "":
        parts.append("End %s" % ended_at)
    var window_status: Dictionary = result.get("window_status", {})
    if typeof(window_status) == TYPE_DICTIONARY and !window_status.is_empty():
        if window_status.get("available", false):
            var cutoff_minutes = int(window_status.get("minutes_until_cutoff", 0))
            if cutoff_minutes > 0:
                parts.append("Window %s" % _format_duration(cutoff_minutes))
        else:
            var resume_minutes = int(window_status.get("resumes_in_minutes", 0))
            if resume_minutes > 0:
                parts.append("Back %s" % _format_duration(resume_minutes))
    var weather_text = _summarize_weather_forecast(result.get("weather_forecast", {}))
    if weather_text != "":
        parts.append(weather_text)
    var zombie_text = _summarize_zombie_forecast(result.get("zombie_forecast", {}))
    if zombie_text != "":
        parts.append(zombie_text)
    return "Recon -> %s" % " | ".join(parts)

func _summarize_weather_forecast(forecast: Dictionary) -> String:
    if typeof(forecast) != TYPE_DICTIONARY or forecast.is_empty():
        return "Weather data unavailable"

    var events: Array = forecast.get("events", [])
    var fragments: PackedStringArray = []

    if events.is_empty():
        var current_state = String(forecast.get("current_state", WeatherSystem.WEATHER_CLEAR))
        fragments.append("Steady %s" % _format_weather_state_label(current_state))
    else:
        for event in events:
            if typeof(event) != TYPE_DICTIONARY:
                continue
            var type = String(event.get("type", ""))
            var minutes = int(event.get("minutes_ahead", 0))
            var time_text = "Now" if minutes == 0 else _format_duration(minutes)
            match type:
                "start":
                    var state = String(event.get("state", WeatherSystem.WEATHER_SPRINKLING))
                    fragments.append("%s -> %s" % [time_text, _format_weather_state_label(state)])
                "stop":
                    fragments.append("%s -> Clear" % time_text)
                "ongoing":
                    var state = String(event.get("state", forecast.get("current_state", WeatherSystem.WEATHER_CLEAR)))
                    var hours_left = int(event.get("hours_remaining", 0))
                    if hours_left > 0:
                        fragments.append("Now -> %s (%dh left)" % [_format_weather_state_label(state), max(hours_left, 0)])
                    else:
                        fragments.append("Now -> %s" % _format_weather_state_label(state))

    if fragments.is_empty():
        return "Weather steady"
    return "Weather: %s" % " / ".join(fragments)

func _summarize_zombie_forecast(forecast: Dictionary) -> String:
    if typeof(forecast) != TYPE_DICTIONARY or forecast.is_empty():
        return ""

    var fragments: PackedStringArray = []
    var active_now = int(forecast.get("active_now", 0))
    if active_now > 0:
        fragments.append("%d nearby" % max(active_now, 0))

    var events: Array = forecast.get("events", [])
    if events.is_empty():
        if fragments.is_empty():
            var horizon = int(forecast.get("minutes_horizon", RECON_OUTLOOK_HOURS * 60))
            fragments.append("Quiet %dh" % max(int(round(horizon / 60.0)), 0))
    else:
        for event in events:
            if typeof(event) != TYPE_DICTIONARY:
                continue
            var spawns = int(event.get("spawns", 0))
            var minutes = int(event.get("minutes_ahead", forecast.get("minutes_horizon", 0)))
            var time_text = "Now" if minutes == 0 else _format_duration(minutes)
            var clock_time = String(event.get("clock_time", ""))
            if clock_time != "":
                time_text = clock_time
            var event_type = String(event.get("type", ""))
            if event_type == "next_day_spawn" and clock_time != "":
                time_text = "Next day %s" % clock_time
            elif event_type == "next_day_spawn":
                time_text = "Next day %s" % time_text
            if spawns > 0:
                fragments.append("%s -> %d arrive" % [time_text, max(spawns, 0)])
            else:
                fragments.append("%s -> No wave" % time_text)

    if fragments.is_empty():
        return "Zombies: Quiet"
    return "Zombies: %s" % " / ".join(fragments)

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
    _forging_feedback_state = state
    if state == "result":
        _set_action_result("forging", text, true)
    else:
        _set_action_default("forging", text, true)

func _lock_forging_feedback():
    _forging_feedback_locked = true
    call_deferred("_unlock_forging_feedback")

func _unlock_forging_feedback():
    _forging_feedback_locked = false

func _set_lead_feedback(text: String, state: String):
    _lead_feedback_state = state
    if state == "result":
        _set_action_result("lead", text, true)
    else:
        _set_action_default("lead", text, true)

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
    var summary = "\n".join(lines)
    meal_summary_label.text = summary
    _set_action_default("meal", summary)

func _update_recon_summary():
    if !is_instance_valid(recon_status_label):
        return
    var parts: PackedStringArray = []
    parts.append("%dh outlook" % RECON_OUTLOOK_HOURS)
    parts.append("-%d cal" % int(round(GameManager.RECON_CALORIE_COST)))
    var window_status: Dictionary = {}
    if game_manager:
        window_status = game_manager.get_recon_window_status()
    var recon_available = window_status.get("available", false)
    if recon_available:
        var cutoff_clock = String(window_status.get("cutoff_at", "12:00 AM"))
        if cutoff_clock != "":
            parts.append("Cutoff %s" % cutoff_clock)
        else:
            var cutoff_minutes = int(window_status.get("minutes_until_cutoff", GameManager.RECON_WINDOW_END_MINUTE))
            parts.append("Cutoff %s" % _format_duration(cutoff_minutes))
    else:
        if window_status.is_empty():
            parts.append("Recon offline")
        else:
            var resume_minutes = int(window_status.get("resumes_in_minutes", 0))
            var resume_label = String(window_status.get("resumes_at", "6:00 AM"))
            if resume_minutes > 0:
                parts.append("Back %s" % _format_duration(resume_minutes))
            elif resume_label != "":
                parts.append("Back at %s" % resume_label)
            else:
                parts.append("Recon offline")
    if time_system:
        parts.append("Dawn %s" % _format_duration(time_system.get_minutes_until_daybreak()))
    if zombie_system and zombie_system.has_active_zombies():
        parts.append("%d undead near" % zombie_system.get_active_zombies())
    var summary = " | ".join(parts)
    recon_status_label.text = summary
    _set_action_default("recon", summary, true)
    if is_instance_valid(recon_select_button):
        recon_select_button.disabled = !recon_available

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
    var summary = " | ".join(lines)
    repair_summary_label.text = summary
    _set_action_default("repair", summary)
func _update_reinforce_summary():
    if !is_instance_valid(reinforce_summary_label):
        return
    var lines: PackedStringArray = []
    lines.append("Reinforce -> +25 hp (cap 150)")
    lines.append("-20% rest / -450 cal")
    var multiplier = game_manager.get_combined_activity_multiplier() if game_manager else 1.0
    var minutes = int(ceil(120.0 * max(multiplier, 0.01)))
    lines.append("Takes %s" % _format_duration(minutes))
    if inventory_system:
        var wood_stock = inventory_system.get_item_count("wood")
        var nail_stock = inventory_system.get_item_count("nails")
        lines.append("Needs 3 wood (Stock %d)" % wood_stock)
        lines.append("Needs 5 nails (Stock %d)" % nail_stock)
    else:
        lines.append("Needs 3 wood & 5 nails")
    if tower_health_system:
        lines.append("Tower %s" % _format_health_snapshot(tower_health_system.get_health()))
    var summary = " | ".join(lines)
    reinforce_summary_label.text = summary
    _set_action_default("reinforce", summary)


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

func _format_weather_state_label(state: String) -> String:
    if weather_system:
        return weather_system.get_state_display_name_for(state)
    return state.capitalize()

func _on_inventory_food_total_changed(new_total: float):
    _update_meal_summary()
    if _forging_feedback_locked:
        return
    if _forging_feedback_state == "offline":
        return
    _set_forging_feedback(_format_forging_ready(new_total), "ready")
func _on_inventory_item_changed(_item_id: String, _quantity_delta: int, _food_delta: float, _total_food_units: float):
    _update_repair_summary()
    _update_reinforce_summary()


func _on_tower_health_changed(_new: float, _old: float):
    _update_repair_summary()
    _update_reinforce_summary()

func _on_lead_zombie_count_changed(count: int):
    if _lead_feedback_locked:
        return
    if _lead_feedback_state == "offline":
        return
    _set_lead_feedback(_format_lead_ready(count), "status")
    _update_recon_summary()

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
