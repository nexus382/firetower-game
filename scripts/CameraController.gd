# CameraController.gd overview:
# - Purpose: hold a static tower-wide frame so UI mockups stay centered.
# - Sections: _ready() pins transform, sets current camera, and logs the setup.
extends Camera2D
class_name CameraController

func _ready():
    print("📷 CameraController initialized")

    _apply_camera_frame()
    get_viewport().size_changed.connect(_on_viewport_resized)

    # Make sure camera is current
    make_current()
    enabled = true

    print("✅ Camera setup complete - fixed view of entire screen")

func _apply_camera_frame():
    # Re-center on the live viewport midpoint so 640-3840 widths stay framed.
    var viewport_rect: Rect2 = get_viewport_rect()
    position = viewport_rect.size * 0.5
    zoom = Vector2.ONE  # Keep native scale for consistent pixel readout.

func _on_viewport_resized():
    _apply_camera_frame()
