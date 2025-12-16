# Visual Representation Prompt for Tap Detection Area

Use this prompt with nanaobanana pro or any AI image generation tool to create a visual diagram showing where the permission tap detection area is currently positioned.

---

## PROMPT:

Create a detailed technical diagram showing an iOS permission dialog screen with a tap detection area overlay for debugging purposes.

### Screen Layout:
- iPhone screen in portrait orientation (typical dimensions: 430 points wide × 932 points tall)
- Dark mode iOS interface with dark background
- At the top: Large title text "Allow 4 Permissions" in bold, rounded system font
- Below title: Progress indicator showing "X/4 permissions allowed" in accent/blue color
- Below that: Video player area or instruction content

### Permission Dialog (iOS Style):
- Modal dialog appears in the center/upper portion of the screen
- Contains app icon at the top
- Permission request text (e.g., "NoteWall would like to access your photos")
- Two buttons at the bottom:
  - "Don't Allow" button on the left (gray/secondary)
  - "Allow" button on the right (blue/primary, typically positioned in top-right area)

### Tap Detection Area (Current Position - RED CIRCLE):
- **Semi-transparent RED CIRCLE** overlay showing the tap detection zone
- **Circle diameter:** 96 points (48 point radius)
- **Position coordinates:**
  - **X (horizontal):** Screen center (215 points) + 140 points offset = **355 points from left edge**
  - **Y (vertical):** 24 points (top padding) + 44 points offset = **68 points from top**
- The circle is positioned **slightly to the RIGHT of screen center** and **near the TOP** of the screen
- This circle represents where the app detects taps to count permission "Allow" button presses
- The circle should visually overlap with where the "Allow" button typically appears in iOS permission dialogs

### Visual Style Requirements:
- Red circle with 50% opacity and 2-point stroke width
- Circle should be clearly visible but not completely obstructing the UI
- Add a label or arrow pointing to the circle saying "Tap Detection Area" or "Current Tap Zone"
- Show the circle positioned relative to the permission dialog's "Allow" button
- Include measurement annotations or grid lines showing:
  - The 140-point horizontal offset (right from center)
  - The 44-point vertical offset (down from top padding)
  - The 96-point diameter of the circle
- Use a technical/diagram style with clear annotations

### Additional Context:
The visual should help developers understand where the tap detection area is positioned relative to the permission dialog's "Allow" button, so they can adjust the offsets (permissionTapAreaXOffset, permissionTapAreaYOffset, permissionTapAreaSize) if the button position doesn't match.

---

## Current Configuration Values:
- **X Offset:** 140 points (moves area to the right)
- **Y Offset:** 44 points (moves area down)
- **Size:** 96 points diameter
- **Actual Position:** 355 points from left, 68 points from top

## How to Adjust:
If the visual shows the tap area doesn't align with the "Allow" button:
- Move right: Increase `permissionTapAreaXOffset` (e.g., 160, 180)
- Move left: Decrease `permissionTapAreaXOffset` (e.g., 120, 100)
- Move down: Increase `permissionTapAreaYOffset` (e.g., 60, 80)
- Move up: Decrease `permissionTapAreaYOffset` (e.g., 30, 20)
- Make larger: Increase `permissionTapAreaSize` (e.g., 120, 150)
- Make smaller: Decrease `permissionTapAreaSize` (e.g., 80, 60)






