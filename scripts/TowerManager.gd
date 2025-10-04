extends Node2D
class_name TowerManager

# Tower layout configuration
var tower_bounds: Rect2
var catwalk_width: float = 0.05  # 5% of tower width

# Room configurations (public for other scripts to access)
var living_area_rect: Rect2
var kitchen_rect: Rect2
var bathroom_rect: Rect2
var inner_bounds: Rect2

# Visual nodes
var inside_view: Node2D

func _ready():
    print("🏗️ TowerManager: Creating tower layout...")
    setup_tower_layout()
    print("✅ Tower layout complete")

func setup_tower_layout():
    """Create the 3-room tower layout with proper scaling"""
    # Get viewport size for responsive layout
    var viewport = get_viewport()
    var screen_size = viewport.get_visible_rect().size
    var screen_width = screen_size.x
    var screen_height = screen_size.y

    # Tower takes 85% of screen, centered
    var tower_width = screen_width * 0.85
    var tower_height = screen_height * 0.85
    var tower_x = (screen_width - tower_width) / 2
    var tower_y = (screen_height - tower_height) / 2

    tower_bounds = Rect2(tower_x, tower_y, tower_width, tower_height)
    print("🏗️ Tower bounds: %s" % tower_bounds)

    # Create the main tower view
    inside_view = Node2D.new()
    inside_view.name = "InsideView"
    add_child(inside_view)

    # Create catwalk (outer border)
    create_catwalk()

    # Adjust catwalk width to be 2x player (approx 32 * 2 = 64) on top/left/bottom
    var catwalk_margin = 64.0
    var right_margin = tower_bounds.size.x * catwalk_width + catwalk_margin
    var inner_rect = Rect2(
        tower_bounds.position + Vector2(catwalk_margin, catwalk_margin),
        Vector2(tower_bounds.size.x - (catwalk_margin + right_margin),
                tower_bounds.size.y - catwalk_margin * 2)
    )
    inner_bounds = inner_rect

    # Divide inner area into rooms
    setup_room_layout(inner_rect)

    # Create room floors
    create_room_floors()

    # Create ladder for location switching
    create_ladder()

    # Create visual walls and collision
    create_walls_and_collision()

func create_catwalk():
    """Create the outer catwalk area"""
    var catwalk_rect = tower_bounds

    var catwalk_node = Node2D.new()
    catwalk_node.name = "Catwalk"
    inside_view.add_child(catwalk_node)

    # Catwalk floor
    var catwalk_floor = ColorRect.new()
    catwalk_floor.size = catwalk_rect.size
    catwalk_floor.position = catwalk_rect.position
    catwalk_floor.color = Color.SADDLE_BROWN
    catwalk_floor.z_index = 0
    catwalk_node.add_child(catwalk_floor)

    # Catwalk walls (visual only)
    create_visual_room_walls(catwalk_node, catwalk_rect)

func setup_room_layout(inner_rect: Rect2):
    """Set up the 3-room layout within the inner area"""
    var inner_width = inner_rect.size.x
    var inner_height = inner_rect.size.y

    # Living Area: left half, full height (subtract wall thickness for shared wall)
    var wall_thickness = 8
    var living_width = (inner_width / 2) - wall_thickness / 2
    living_area_rect = Rect2(inner_rect.position, Vector2(living_width, inner_height))

    # Kitchen: top right, 60% height
    var kitchen_width = (inner_width - living_width - wall_thickness)
    var kitchen_height = inner_height * 0.6 - wall_thickness / 2
    kitchen_rect = Rect2(
        inner_rect.position + Vector2(living_width + wall_thickness, 0),
        Vector2(kitchen_width, kitchen_height)
    )

    # Bathroom: bottom right, 40% height
    var bathroom_width = kitchen_width
    var bathroom_height = inner_height - kitchen_height - wall_thickness
    bathroom_rect = Rect2(
        inner_rect.position + Vector2(living_width + wall_thickness, kitchen_height + wall_thickness),
        Vector2(bathroom_width, bathroom_height)
    )

    print("🏗️ Room layout:")
    print("  Living Area: %s" % living_area_rect)
    print("  Kitchen: %s" % kitchen_rect)
    print("  Bathroom: %s" % bathroom_rect)

func create_walls_and_collision():
    """Create walls with collision and doorways"""
    var wall_thickness = 8

    # Create outer tower walls (catwalk boundary) - no doorways needed
    create_wall_with_collision(tower_bounds.position, Vector2(tower_bounds.size.x, wall_thickness))  # Top
    create_wall_with_collision(Vector2(tower_bounds.position.x, tower_bounds.position.y + tower_bounds.size.y - wall_thickness),
                              Vector2(tower_bounds.size.x, wall_thickness))  # Bottom
    create_wall_with_collision(tower_bounds.position, Vector2(wall_thickness, tower_bounds.size.y))  # Left
    create_wall_with_collision(Vector2(tower_bounds.position.x + tower_bounds.size.x - wall_thickness, tower_bounds.position.y),
                              Vector2(wall_thickness, tower_bounds.size.y))  # Right

    # Create inner walls with doorways
    create_inner_walls_with_doorways(wall_thickness)

    # Create doorway from Living Area to Catwalk
    create_catwalk_doorway(wall_thickness)

func create_inner_walls_with_doorways(wall_thickness: float):
    """Create walls between rooms with proper doorway gaps"""
    var doorway_size = 100  # Increased for visibility

    print("🏗️ Creating inner walls with doorways...")

    # Inner top boundary (no doorway)
    create_wall_with_collision(Vector2(inner_bounds.position.x, inner_bounds.position.y),
                               Vector2(inner_bounds.size.x, wall_thickness))

    # Inner bottom boundary (no doorway)
    create_wall_with_collision(Vector2(inner_bounds.position.x,
                                       inner_bounds.position.y + inner_bounds.size.y - wall_thickness),
                               Vector2(inner_bounds.size.x, wall_thickness))

    # Inner right boundary (no doorway)
    create_wall_with_collision(Vector2(inner_bounds.position.x + inner_bounds.size.x - wall_thickness,
                                       inner_bounds.position.y),
                               Vector2(wall_thickness, inner_bounds.size.y))

    # Vertical wall between Living Area and Kitchen/Bathroom area
    # Create wall segments that avoid the doorway area
    print("🏗️ Creating vertical wall between Living Area and Kitchen/Bathroom")
    create_vertical_wall_with_doorway(
        living_area_rect.position.x + living_area_rect.size.x,  # x position
        living_area_rect.position.y,                           # y position
        living_area_rect.size.y,                              # height
        doorway_size,                                          # doorway size
        wall_thickness                                         # wall thickness
    )

    # Horizontal wall between Kitchen and Bathroom
    # Create wall segments that avoid the doorway area
    print("🏗️ Creating horizontal wall between Kitchen and Bathroom")
    var shared_width = max(kitchen_rect.size.x, bathroom_rect.size.x)
    create_horizontal_wall_with_doorway(
        kitchen_rect.position.x,                               # x position
        kitchen_rect.position.y + kitchen_rect.size.y,        # y position
        shared_width,                                          # width
        doorway_size,                                          # doorway size
        wall_thickness                                         # wall thickness
    )

func create_wall_with_collision(pos: Vector2, size: Vector2):
    """Create a wall with both visual and collision components"""
    var wall = StaticBody2D.new()
    wall.position = pos
    wall.collision_layer = 1  # Layer 1 for walls
    wall.collision_mask = 1   # Collide with layer 1 (player)
    wall.name = "Wall_%d_%d" % [pos.x, pos.y]

    # Collision component
    var collision = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = size
    collision.shape = shape
    collision.position = size / 2
    wall.add_child(collision)

    # Visual component
    var visual = ColorRect.new()
    visual.size = size
    visual.position = Vector2.ZERO
    visual.color = Color.DARK_GRAY
    visual.z_index = 1
    wall.add_child(visual)

    inside_view.add_child(wall)

func create_doorway_marker(pos: Vector2, size: Vector2, color: Color = Color.SILVER):
    """Create a thick visual marker indicating a doorway"""
    var marker = ColorRect.new()
    marker.position = pos
    marker.size = size
    marker.color = color
    marker.z_index = 3
    inside_view.add_child(marker)

func create_room_floors():
    """Create the floor for each room with different colors"""
    # Living Area - main living space
    create_room_floor("LivingArea", living_area_rect, Color.SANDY_BROWN)

    # Kitchen - food preparation area
    create_room_floor("Kitchen", kitchen_rect, Color.ORANGE)

    # Bathroom - healing area
    create_room_floor("Bathroom", bathroom_rect, Color.LIGHT_BLUE)

func create_room_floor(room_name: String, rect: Rect2, color: Color):
    """Create a floor for a specific room"""
    var room_node = Node2D.new()
    room_node.name = room_name
    inside_view.add_child(room_node)

    # Room floor
    var floor = ColorRect.new()
    floor.size = rect.size
    floor.position = rect.position
    floor.color = color
    floor.z_index = 0
    room_node.add_child(floor)

    # Room label
    var label = Label.new()
    label.text = room_name
    label.position = rect.position + Vector2(15, 15)
    label.add_theme_color_override("font_color", Color.BLACK)
    label.add_theme_font_size_override("font_size", 14)
    label.z_index = 2
    room_node.add_child(label)

    # Create visual walls for this room (no collision)
    create_visual_room_walls(room_node, rect)

func create_ladder():
    """Create a ladder for location switching in the Living Area"""
    var ladder_pos = living_area_rect.position + living_area_rect.size / 2

    var ladder = Area2D.new()
    ladder.name = "Ladder"
    ladder.position = ladder_pos

    # Ladder visual
    var ladder_visual = ColorRect.new()
    ladder_visual.size = Vector2(30, 60)
    ladder_visual.position = Vector2(-15, -30)
    ladder_visual.color = Color.BROWN
    ladder.add_child(ladder_visual)

    # Ladder label
    var ladder_label = Label.new()
    ladder_label.text = "Ladder"
    ladder_label.position = Vector2(-15, -50)
    ladder_label.add_theme_color_override("font_color", Color.WHITE)
    ladder_label.add_theme_font_size_override("font_size", 12)
    ladder.add_child(ladder_label)

    # Ladder collision
    var collision = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = Vector2(30, 60)
    collision.shape = shape
    collision.position = Vector2(0, 0)
    ladder.add_child(collision)

    # Add to interactable group for player interaction
    ladder.add_to_group("interactable")

    inside_view.add_child(ladder)
    print("🏗️ Created ladder at: %s" % ladder_pos)

func create_vertical_wall_with_doorway(x: float, y: float, height: float, doorway_size: float, wall_thickness: float):
    """Create a vertical wall with a doorway gap in the middle"""
    var doorway_center_y = height / 2
    var doorway_start_y = doorway_center_y - doorway_size / 2
    var doorway_end_y = doorway_center_y + doorway_size / 2

    # Wall above doorway
    if doorway_start_y > 0:
        create_wall_with_collision(Vector2(x, y), Vector2(wall_thickness, doorway_start_y))

    # Wall below doorway
    if doorway_end_y < height:
        create_wall_with_collision(Vector2(x, y + doorway_end_y), Vector2(wall_thickness, height - doorway_end_y))

    # Visual doorway marker
    create_doorway_marker(Vector2(x - wall_thickness, y + doorway_start_y), Vector2(wall_thickness * 3, doorway_size))

func create_horizontal_wall_with_doorway(x: float, y: float, width: float, doorway_size: float, wall_thickness: float):
    """Create a horizontal wall with a doorway gap in the middle"""
    var doorway_center_x = width / 2
    var doorway_start_x = doorway_center_x - doorway_size / 2
    var doorway_end_x = doorway_center_x + doorway_size / 2

    # Wall left of doorway
    if doorway_start_x > 0:
        create_wall_with_collision(Vector2(x, y), Vector2(doorway_start_x, wall_thickness))

    # Wall right of doorway
    if doorway_end_x < width:
        create_wall_with_collision(Vector2(x + doorway_end_x, y), Vector2(width - doorway_end_x, wall_thickness))

    # Visual doorway marker
    create_doorway_marker(Vector2(x + doorway_start_x, y - wall_thickness), Vector2(doorway_size, wall_thickness * 3))

func create_catwalk_doorway(wall_thickness: float):
    """Create a doorway from Living Area to Catwalk (west/catwalk side)"""
    if inner_bounds == null:
        return

    var doorway_size = 100  # Wider doorway for visibility as requested

    # We'll place the doorway centered vertically on the western side of the inner bounds
    var doorway_center_y = inner_bounds.position.y + inner_bounds.size.y / 2
    var doorway_start_y = doorway_center_y - doorway_size / 2
    var doorway_end_y = doorway_center_y + doorway_size / 2

    # Create two doorway markers for visual emphasis (thicker lines)
    create_doorway_marker(Vector2(inner_bounds.position.x - wall_thickness, doorway_start_y), Vector2(wall_thickness * 3, doorway_size))

    # Wall above doorway (on inner boundary of catwalk)
    if doorway_start_y > inner_bounds.position.y:
        create_wall_with_collision(Vector2(inner_bounds.position.x, inner_bounds.position.y),
                                  Vector2(wall_thickness, doorway_start_y - inner_bounds.position.y))

    # Wall below doorway (on inner boundary of catwalk)
    var lower_wall_height = (inner_bounds.position.y + inner_bounds.size.y) - doorway_end_y
    if lower_wall_height > 0:
        create_wall_with_collision(Vector2(inner_bounds.position.x, doorway_end_y),
                                  Vector2(wall_thickness, lower_wall_height))

func create_visual_room_walls(parent: Node2D, rect: Rect2):
    """Create visual walls around a room (no collision)"""
    var wall_color = Color.DARK_GRAY
    var wall_thickness = 8

    # Top wall
    var top_wall = ColorRect.new()
    top_wall.position = rect.position
    top_wall.size = Vector2(rect.size.x, wall_thickness)
    top_wall.color = wall_color
    top_wall.z_index = 1
    parent.add_child(top_wall)

    # Bottom wall
    var bottom_wall = ColorRect.new()
    bottom_wall.position = Vector2(rect.position.x, rect.position.y + rect.size.y - wall_thickness)
    bottom_wall.size = Vector2(rect.size.x, wall_thickness)
    bottom_wall.color = wall_color
    bottom_wall.z_index = 1
    parent.add_child(bottom_wall)

    # Left wall
    var left_wall = ColorRect.new()
    left_wall.position = rect.position
    left_wall.size = Vector2(wall_thickness, rect.size.y)
    left_wall.color = wall_color
    left_wall.z_index = 1
    parent.add_child(left_wall)

    # Right wall
    var right_wall = ColorRect.new()
    right_wall.position = Vector2(rect.position.x + rect.size.x - wall_thickness, rect.position.y)
    right_wall.size = Vector2(wall_thickness, rect.size.y)
    right_wall.color = wall_color
    right_wall.z_index = 1
    parent.add_child(right_wall)

func create_room_walls(parent: Node2D, rect: Rect2):
    """Create walls with collision around a room"""
    var wall_thickness = 8

    # Top wall
    create_wall_with_collision(rect.position, Vector2(rect.size.x, wall_thickness))

    # Bottom wall
    create_wall_with_collision(Vector2(rect.position.x, rect.position.y + rect.size.y - wall_thickness),
                              Vector2(rect.size.x, wall_thickness))

    # Left wall
    create_wall_with_collision(rect.position, Vector2(wall_thickness, rect.size.y))

    # Right wall
    create_wall_with_collision(Vector2(rect.position.x + rect.size.x - wall_thickness, rect.position.y),
                              Vector2(wall_thickness, rect.size.y))