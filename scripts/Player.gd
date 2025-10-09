# Player.gd overview:
# - Purpose: drive avatar input, apply normalized velocity, and snap start position to living area center.
# - Sections: constants set movement speed, lifecycle hooks wire placement, helpers process directional input.
extends CharacterBody2D
class_name Player

# SPEED controls base movement in pixels/sec (keep between 150.0 - 275.0 for feel).
const SPEED = 200.0

func _ready():
    print("🎮 Player initialized at position: %s" % position)

    # Connect to tower manager for positioning
    var tower_manager = get_node("../TowerManager")
    if tower_manager:
        # Position player in the center of the Living Area
        var living_center = tower_manager.living_area_rect.position + tower_manager.living_area_rect.size / 2
        position = living_center
        print("🎮 Player positioned in Living Area center: %s" % position)

func _physics_process(delta):
    handle_movement()

    # Apply movement
    var collision = move_and_slide()
    if collision:
        print("🎮 Player collision detected")

func handle_movement():
    # Collect intended direction first so we can normalize diagonals before applying speed.
    var direction = Vector2.ZERO

    # Get input direction
    if Input.is_action_pressed("move_up"):
        direction.y -= 1
    if Input.is_action_pressed("move_down"):
        direction.y += 1
    if Input.is_action_pressed("move_left"):
        direction.x -= 1
    if Input.is_action_pressed("move_right"):
        direction.x += 1

    # Normalize diagonal movement
    if direction.length() > 1:
        direction = direction.normalized()

    # Apply movement
    velocity = direction * SPEED

    # Debug movement
    if direction != Vector2.ZERO:
        print("🎮 Moving: direction=%s, velocity=%s" % [direction, velocity])
