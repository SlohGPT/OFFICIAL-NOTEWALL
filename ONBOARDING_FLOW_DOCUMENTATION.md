# NoteWall Onboarding Flow - Complete Documentation

## Overview

The NoteWall onboarding flow is a comprehensive, step-by-step guide designed to help users set up their lock screen wallpaper with personalized notes. The flow consists of 6 main steps (plus a pre-onboarding hook and final overview) that guide users through installation, configuration, and permission setup. Two key video guides with accompanying text versions help users understand critical setup requirements.

---

## Onboarding Flow Structure

The onboarding consists of the following steps in order:

1. **Pre-Onboarding Hook** (Animation intro)
2. **Step 1: Welcome** (Introduction to NoteWall)
3. **Step 2: Video Introduction** (Welcome video guide with text version)
4. **Step 3: Install Shortcut** (Shortcut installation with troubleshooting)
5. **Step 4: Add Notes** (Create initial notes)
6. **Step 5: Choose Wallpapers** (Configure wallpaper preferences)
7. **Step 6: Allow Permissions** (Grant system permissions)
8. **Overview** (Final summary)

---

## Step-by-Step Detailed Breakdown

### Pre-Onboarding Hook

**Purpose**: Visual introduction with animated note cards and tagline to create engagement before the actual onboarding begins.

**User Experience**:
- Animated note cards fly in from different directions
- Mockup preview appears with floating animation
- Tagline: "You forget things for one simple reason: you don't see them. NoteWall fixes that."
- "Get Started" button appears to begin onboarding

**User Action Required**: Tap "Get Started" to proceed

---

### Step 1: Welcome

**Purpose**: Introduce the core value proposition of NoteWall.

**Content**:
- Large title: "Turn Every Pickup Into Focus"
- Subtitle explaining the concept
- Three highlight cards explaining benefits:
  1. **Turn Every Pickup Into Focus**: "You pick up your phone up to 498× per day. Now each one becomes a reminder of what matters."
  2. **Keep Your Goals Always in Sight**: "Your lock screen becomes a visual cue you can't ignore."
  3. **Beat Scrolling Before It Starts**: "See your goals before TikTok, Instagram, or distractions."

**User Action Required**: Tap "Next" to continue

---

### Step 2: Video Introduction (Welcome Video Guide)

**Purpose**: Educate users about Apple's Shortcuts limitation regarding wallpaper presets before they attempt shortcut installation.

**Two Presentation Modes**: Users can toggle between video and text versions

#### Video Version

**Video Resource**: `welcome-video.mp4`

**Video Features**:
- Auto-playing, looping video
- Custom video controls:
  - Mute/Unmute button (top-left corner of video)
  - Pause/Play button (top-right corner of video)
  - Skip backward 3 seconds (left side of video)
  - Skip forward 3 seconds (right side of video)
  - Progress bar at top of video
- Video is displayed at 70% screen width with rounded corners and shadow
- Aspect ratio: 9:16 (portrait)

**Video Content**: Explains that Apple's Shortcuts app has a limitation - it can only work with photo-based wallpapers, not Apple's built-in presets (gradients, astronomy pictures, emoji wallpapers, etc.).

#### Text Version (Toggle Available)

When users tap "Text version" button, they see a comprehensive written explanation:

**Key Points Covered**:

1. **Quick Heads Up Card**
   - Introduction that there's something important to know before installing the shortcut

2. **Apple's Shortcut Limitation Card**
   - Explanation that shortcuts can only work with wallpapers using photos/images from the library
   - What this means: If user is using Apple's built-in presets, the shortcut won't be able to select them
   - Highlight box emphasizing this is an Apple limitation, not a NoteWall bug

3. **What Happens If You Have an Apple Preset? Card**
   - When installing the shortcut, users see a list of wallpapers to choose from
   - If using an Apple preset, the list will be empty or grayed out
   - Users won't be able to tap any options

4. **Don't Worry - Easy Fix! Card**
   - Solution: Create a new wallpaper using a NoteWall image (saved to Photos)
   - Takes about 2 minutes
   - Guided step-by-step instructions provided
   - Most people with photo-based wallpapers complete setup in ~90 seconds

5. **Ready? Let's Do This! Card**
   - Call to action

**Important Safari Requirement**:
- Before proceeding to shortcut installation, users must confirm they have Safari installed
- If Safari is not detected, users are prompted to download it from the App Store
- Safari is required for the shortcut to work properly

**User Action Required**: 
- Watch video or read text version
- Confirm Safari is installed (if prompted)
- Tap "Continue" to proceed to shortcut installation

---

### Step 3: Install Shortcut

**Purpose**: Guide users through installing the NoteWall shortcut from iCloud.

**Shortcut URL**: `https://www.icloud.com/shortcuts/4735a1723f8a4cc28c12d07092c66a35`

#### Initial Installation Process

**User Experience**:
1. User taps "Install & Continue" button
2. App opens Safari/Shortcuts app with the shortcut URL
3. Picture-in-Picture (PiP) video plays showing installation steps (if available)
4. User installs the shortcut in the Shortcuts app
5. App detects when user returns from Shortcuts app
6. Shows "Installation Check" screen

#### Installation Check Screen

After returning from Shortcuts app, users see:

**Title**: "Installation Check"
**Question**: "Were you able to select a wallpaper?"

**Two Response Options**:

1. **"Yes, It Worked!" Button**
   - User successfully selected a wallpaper from the list
   - Advances to Step 4 (Add Notes)
   - Shortcut installation was successful

2. **"No, Got Stuck" Button**
   - Opens troubleshooting modal with "How-to-Fix Guide"

#### Troubleshooting: How-to-Fix Guide

**Purpose**: Help users who couldn't select a wallpaper (typically because they're using Apple's preset wallpapers).

**Trigger**: User taps "No, Got Stuck" on Installation Check screen

**Two Presentation Modes**: Video and text versions (toggleable)

##### How-to-Fix Video Version

**Video Resource**: `how-to-fix-guide.mp4`

**Video Features**:
- Auto-playing, looping video
- Same custom controls as welcome video (mute, pause, skip forward/backward, progress bar)
- Shows step-by-step visual instructions for fixing the wallpaper issue

##### How-to-Fix Text Version

**Title**: "Why Couldn't You Select a Wallpaper?"

**Key Content Cards**:

1. **The Problem: Apple's Limitation**
   - Explains user is using Apple's built-in preset wallpaper
   - Apple designed Shortcuts to only work with photo-based wallpapers
   - This is an Apple limitation, not a NoteWall bug

2. **We've Saved a Special Image for You**
   - Shows the "InstructionWallpaper" image (bright red image with "SET THIS AS YOUR WALLPAPER" text)
   - This image will be saved to Photos
   - Explains it's temporary - can be changed later to custom image with notes

3. **The Easy Fix**
   - Need to set up a photo-based wallpaper
   - Takes about 2 minutes
   - **Detailed Step-by-Step Instructions**:
     
     **Step 1**: Open Photos
     - Tap "Open Photos" button below
     - Opens Photos app to Recents album
     
     **Step 2**: Find the RED Image
     - Look in Recents album for the red image
     - If not in Recents, check "All Photos" and scroll to most recent images
     
     **Step 3**: Long-Press the Image
     - Long-press (press and hold) on the red image
     
     **Step 4**: Tap SHARE
     - Tap "SHARE" from the menu that appears
     
     **Step 5**: Use as Wallpaper
     - Scroll down and tap "Use as Wallpaper" from the menu
     
     **Step 6**: Set as Lock Screen
     - See preview
     - Tap "Add" in top right corner
     - Tap "Set as wallpaper pair"
     
     **Step 7**: Return to NoteWall App
     - Swipe up to go back to NoteWall app

4. **What Happens Next?**
   - Once red image is set as wallpaper, return to app
   - Go back to shortcut installation step
   - This time, wallpaper will appear in list and can be selected
   - Shortcut will work perfectly after this

**Primary Action Button**: "Open Photos"
- Saves instruction wallpaper to Photos
- Opens Photos app automatically

**Secondary Action**: "I'll Do This Later" (dismisses troubleshooting)

#### "Ready to Try Again?" Screen

After user completes the fix and returns to Step 3:

**Content**:
- Success confirmation: "All Set!"
- Message: "Great job! Your photo-based wallpaper is ready. The shortcut installation will work perfectly this time."
- Note: "This next attempt should only take 30 seconds."
- Button: "Install Shortcut Again" - Opens shortcut installation process again

**User Action Required**: 
- Install shortcut from provided URL
- Return to app
- Confirm whether wallpaper selection worked or got stuck
- If stuck, follow troubleshooting guide to set photo-based wallpaper
- Confirm successful installation

---

### Step 4: Add Notes

**Purpose**: Create initial notes that will appear on the lock screen wallpaper.

**User Interface**:
- Title: "Add Your First Notes"
- Subtitle: "These notes will appear on your lock screen wallpaper"
- Notes list display (numbered)
- Input field: "Type a note..."
- Plus button to add note
- Delete button (X) on each note

**Validation**:
- At least one note is required to continue
- Continue button is disabled until at least one note is added
- Empty state message: "Add at least one note to continue"

**Features**:
- Auto-focus on text field when step appears
- Notes are numbered (1, 2, 3, etc.)
- Notes can be deleted by tapping X button
- Keyboard dismisses when tapping outside input area
- Smooth animations for adding/removing notes

**User Action Required**: 
- Add at least one note
- Can add multiple notes
- Tap "Continue" to proceed (button only enabled when notes exist)

---

### Step 5: Choose Wallpapers

**Purpose**: Configure wallpaper preferences for both home screen and lock screen.

**Requirements**: iOS 16.0+ for photo picker functionality

#### Home Screen Wallpaper Configuration

Users can choose one of two options:

1. **Custom Photo** (via Photo Picker)
   - Tap to open photo picker
   - Select photo from Photos library
   - Photo is saved and will be used as home screen background
   - Status message confirms when photo is saved

2. **Quick Presets** (Black, Gray, or White)
   - Three preset options available
   - Black preset
   - Gray preset  
   - White preset
   - Tap to select and save preset
   - Status message confirms selection

**Note**: If user doesn't select anything, shortcut will reuse current home screen wallpaper

#### Lock Screen Background Configuration

Users configure the background for the lock screen wallpaper where notes will appear:

**Options**:

1. **Photo Mode**
   - Select custom photo from Photos library
   - Photo will be used as background for lock screen
   - Notes will overlay on top of this photo

2. **Color Mode**
   - Choose from preset color options:
     - Black
     - Gray
     - White
     - Other color options
   - Solid color background for notes

3. **Not Selected** (Default)
   - Uses system default or current lock screen background

**Status Messages**: 
- Confirmation when photo is saved
- Error messages if save fails
- Loading indicators during save process

#### Lock Screen Widgets Toggle

**Setting**: "I use lock screen widgets"

**Options**:
- **Enabled** (default): Notes start appearing lower to avoid widgets below the time
- **Disabled**: Notes start closer to the time for more space and aesthetic look

**Impact**: Adjusts vertical positioning of notes on lock screen to accommodate widgets

#### Additional Features

- **Edit Notes Button**: Allows returning to Step 4 to modify notes
- **Help Button**: Access support/help resources

**User Action Required**:
- (Optional) Select home screen wallpaper (custom photo or preset)
- (Optional) Configure lock screen background (photo, color, or leave as default)
- Toggle lock screen widgets setting if applicable
- Tap "Next" to continue

**Note**: When user taps "Next", the app:
1. Generates the initial lock screen wallpaper with user's notes
2. Saves wallpaper images to app's internal storage
3. Advances to Step 6 (Permissions)

---

### Step 6: Allow Permissions

**Purpose**: Guide users through granting the three required system permissions for NoteWall to function.

**Visual Guide**:
- Title: "Allow 3 Permissions"
- Three upward-pointing chevrons indicating where permission popups appear
- Hint text: "Permission popups appear here"
- Instruction: "click ALLOW for all"

#### Video Guide

**Video Resource**: `notifications-of-permissions.mp4`

**Video Content**: Shows example of the three permission popups appearing on screen, demonstrating that user should tap "Allow" for each one.

**Video Features**:
- Auto-playing, looping video
- Custom video player with controls
- Cropped to remove black bars
- Shows the actual permission request UI

#### The Three Required Permissions

1. **Shortcuts Folder Access - Home Screen**
   - Requested when shortcut first runs
   - Permission dialog: "NoteWall would like to access 'HomeScreen' folder"
   - User must tap "Allow" or "Always Allow"
   - Required for shortcut to save home screen wallpapers

2. **Shortcuts Folder Access - Lock Screen**
   - Requested when shortcut first runs
   - Permission dialog: "NoteWall would like to access 'LockScreen' folder"
   - User must tap "Allow" or "Always Allow"
   - Required for shortcut to save lock screen wallpapers

3. **Notifications Permission**
   - Requested by NoteWall app
   - iOS system permission dialog
   - User must tap "Allow"
   - Required for wallpaper update notifications

#### Permission Confirmation

**Confirmation Checkbox**: 
- Text: "I've granted all 3 Permissions"
- User must check this box to continue
- Checkbox state: Empty circle → Checked circle with accent color

**Note**: The app doesn't automatically detect permissions - user must manually confirm they've granted all three.

**User Action Required**:
1. Watch video guide showing permission popups
2. When permission popups appear, tap "Allow" for each one:
   - Allow HomeScreen folder access
   - Allow LockScreen folder access
   - Allow Notifications
3. Check the confirmation checkbox: "I've granted all 3 Permissions"
4. Tap "Continue" button (only enabled when checkbox is checked)

**Important**: All three permissions must be granted for NoteWall to function properly. The shortcut cannot save wallpapers without folder access, and notifications are used to inform users when wallpapers are updated.

---

### Overview (Final Step)

**Purpose**: Celebrate completion and provide final guidance for using NoteWall.

#### Transition Animation

Before showing overview, there's a celebratory transition:

**Transition Sequence**:
1. Animated words appear: "You're" → "All" → "Set" → "!"
2. Countdown: 3 → 2 → 1
3. Confetti explosion
4. Transition to overview screen

#### Overview Content

**Hero Card**: "Ready to Go"
- Summary: "You've got everything set up. Keep these quick highlights in mind as you start using NoteWall."
- Next steps information

**Info Cards**:

1. **Add & Edit Notes**
   - Explanation of how to manage notes in the app
   - Notes appear on lock screen wallpaper

2. **Update Wallpaper**
   - How wallpaper updates when notes change
   - Automatic updates via shortcut

3. **Customize Appearance**
   - Settings available for customization
   - Wallpaper preferences

**Pro Tip Card**: "Make it automatic"
- Create Shortcuts automation suggestions:
  - Trigger every morning
  - Pair with Focus mode
  - Use personal automation (arrive at office, start commute, etc.)

**User Action Required**: 
- Tap "Start Using NoteWall" to complete onboarding
- App marks onboarding as complete
- User enters main app interface

---

## Key Video Guides Summary

### 1. Welcome Video (Step 2)

**File**: `welcome-video.mp4`

**Purpose**: Explain Apple's Shortcuts limitation before shortcut installation

**Key Message**: 
- Shortcuts only work with photo-based wallpapers
- Apple presets won't work
- If user has preset, they'll need to set a photo-based wallpaper first
- Easy fix is provided (2-minute process)

**Text Version Content**:
- Detailed explanation of the limitation
- What happens if user has Apple preset
- Step-by-step fix instructions
- Reassurance that it's an Apple limitation, not a bug

### 2. How-to-Fix Guide (Step 3 Troubleshooting)

**File**: `how-to-fix-guide.mp4`

**Purpose**: Guide users through fixing wallpaper selection issue

**Key Message**:
- Problem: Using Apple preset wallpaper
- Solution: Set the red instruction wallpaper as lock screen
- 7-step process detailed in text version

**Text Version Content**:
- Explanation of the problem
- Shows the red instruction wallpaper image
- Detailed 7-step instructions:
  1. Open Photos
  2. Find RED image
  3. Long-press image
  4. Tap SHARE
  5. Use as Wallpaper
  6. Set as Lock Screen
  7. Return to app
- What happens next after fix

### 3. Notifications Permissions Video (Step 6)

**File**: `notifications-of-permissions.mp4`

**Purpose**: Show users what the three permission popups look like

**Key Message**:
- Three permission popups will appear
- Must tap "Allow" for all three
- Visual demonstration of each popup

---

## Critical Setup Requirements

### Must-Have Requirements

1. **Safari Browser**: Required for shortcut to work properly
   - Checked before Step 3
   - User must confirm installation or download from App Store

2. **Photo-Based Wallpaper**: Lock screen must use a photo-based wallpaper for shortcut to work
   - If using Apple preset, must follow "How-to-Fix" guide
   - Set the red instruction wallpaper temporarily
   - Can be changed to custom photo later

3. **Shortcut Installation**: Must successfully install shortcut from iCloud URL
   - URL: `https://www.icloud.com/shortcuts/4735a1723f8a4cc28c12d07092c66a35`
   - Must be able to select wallpaper from list during installation
   - If can't select, must complete fix process first

4. **At Least One Note**: Required to proceed from Step 4
   - Notes are the core content displayed on wallpaper
   - Multiple notes supported

5. **Three Permissions**: All must be granted
   - HomeScreen folder access
   - LockScreen folder access
   - Notifications permission

### Optional Configurations

1. **Home Screen Wallpaper**: Can use custom photo or preset (optional)
2. **Lock Screen Background**: Can customize with photo or color (optional, has defaults)
3. **Lock Screen Widgets Toggle**: Adjusts note positioning (default: enabled)

---

## User Journey Flow Chart

```
Pre-Onboarding Hook
    ↓
Step 1: Welcome (Value Proposition)
    ↓
Step 2: Video Introduction (Welcome Video)
    ├─ Video Version (auto-playing)
    └─ Text Version (toggleable)
    ↓
Safari Check (if needed)
    ↓
Step 3: Install Shortcut
    ├─ Success Path: "Yes, It Worked!" → Step 4
    └─ Issue Path: "No, Got Stuck" → Troubleshooting
        ├─ How-to-Fix Video
        ├─ How-to-Fix Text Version
        └─ User fixes wallpaper → "Ready to Try Again?" → Retry installation
    ↓
Step 4: Add Notes
    ↓
Step 5: Choose Wallpapers
    ├─ Home Screen: Custom Photo OR Preset
    ├─ Lock Screen Background: Photo OR Color OR Default
    └─ Lock Screen Widgets: Toggle
    ↓ (Generates initial wallpaper)
Step 6: Allow Permissions
    ├─ Permissions Video Guide
    ├─ Grant HomeScreen folder access
    ├─ Grant LockScreen folder access
    ├─ Grant Notifications permission
    └─ Confirm checkbox
    ↓
Transition Animation (Countdown + Confetti)
    ↓
Overview (Final Summary)
    ↓
Complete Onboarding → Main App
```

---

## Technical Implementation Details

### Video Handling

- Videos use `AVQueuePlayer` with `AVPlayerLooper` for seamless looping
- Custom video controls implemented (mute, pause, skip, progress)
- Videos can be loaded from remote URLs (via Config) or app bundle (fallback)
- PiP (Picture-in-Picture) support for shortcut installation video
- Video playback automatically pauses/resumes based on app state

### Permission Tracking

- Uses simple checkbox confirmation (doesn't auto-detect permissions)
- User manually confirms they've granted all three permissions
- Actual permission status checked later when shortcut runs

### Wallpaper Generation

- Generated in Step 5 after user configures preferences
- Saved to app's internal storage (`HomeScreenImageManager`)
- Lock screen wallpaper includes user's notes overlaid on background
- Preview available in final overview step

### State Management

- Uses `@AppStorage` for persistence across app launches
- Onboarding version tracked to handle updates
- Step progression managed via `OnboardingPage` enum
- Notes stored as JSON data

---

## Text Version Content (Complete)

### Step 2 Text Version - Welcome Guide

**Title**: "Important Setup Information"
**Subtitle**: "Before we install the shortcut"

**Card 1: Quick Heads Up**
- "Hey! Before we install the shortcut, there's something important you need to know."

**Card 2: Apple's Shortcut Limitation**
- "Apple's Shortcuts app has a quirk that affects how wallpapers work. The shortcut can only work with wallpapers that use photos or images from your library."
- "If your current lock screen wallpaper is one of Apple's built-in presets - like those colorful gradients, astronomy pictures, emoji wallpapers, or any of Apple's default designs - the shortcut won't be able to select it in the next step."
- Highlight box: "This isn't a bug with NoteWall. It's a limitation Apple built into the Shortcuts app. They only allow shortcuts to work with photo-based wallpapers, not their built-in preset designs."

**Card 3: What Happens If You Have an Apple Preset?**
- "When you try to install the shortcut, you'll see a list of wallpapers to choose from. If you're using an Apple preset, that list will be empty or all the options will be grayed out and you won't be able to tap any of them."

**Card 4: Don't Worry - Easy Fix!**
- "I'll show you exactly how to fix it. The solution is simple: we'll create a new wallpaper using a NoteWall image (which will be saved to your Photos). This takes about 2 minutes, and I'll guide you through every step."
- "For most people, this setup works perfectly the first time. If you already have a photo-based wallpaper, you'll breeze through the next step in about 90 seconds."

**Card 5: Ready? Let's Do This!**
- Call to action

### Step 3 Text Version - How-to-Fix Guide

**Title**: "Why Couldn't You Select a Wallpaper?"

**Card 1: The Problem: Apple's Limitation**
- "The reason you couldn't select any wallpaper is simple: You're currently using one of Apple's built-in wallpaper presets."
- "Apple designed the Shortcuts app to only work with wallpapers that use photos from your library. It cannot work with Apple's built-in preset wallpapers - like gradients, astronomy images, emoji designs, or any of their default wallpapers."
- Highlight box: "This isn't a NoteWall bug. It's an Apple limitation that affects all shortcuts that try to modify wallpapers."

**Card 2: We've Saved a Special Image for You**
- Shows instruction wallpaper image (red image with "SET THIS AS YOUR WALLPAPER" text)
- "This bright red image will be saved to your Photos once you click the continue button below. It says 'SET THIS AS YOUR WALLPAPER' - that's exactly what you need to do!"
- "Don't worry - this is temporary. Once you've set it up and the shortcut works, you can change it to your own custom image wallpaper with your notes on it."

**Card 3: The Easy Fix**
- "We need to set up a photo-based wallpaper so the shortcut can work. The red image is saved to your Photos - let's set it as your wallpaper now."
- "This takes about 2 minutes. Here's exactly what to do:"

**Step-by-Step Instructions:**

1. **Open Photos**
   - "Tap the 'Open Photos' button below. This will open your Photos app to the Recents album where this red bright image should be."

2. **Find the RED Image**
   - "Look in the Recents album - the red image should be there. If you don't see it in Recents, check your 'All Photos' and scroll to the most recent images."

3. **Long-Press the Image**
   - "Long-press (press and hold) on it."

4. **Tap SHARE**
   - "Tap SHARE from the menu that appears."

5. **Use as Wallpaper**
   - "Scroll down a bit and then tap the 'Use as Wallpaper' from the menu that appears."

6. **Set as Lock Screen**
   - "You'll see a preview. Tap add in top right corner and then Set as wallpaper pair."

7. **Return to NoteWall App**
   - "Swipe up to go back to NoteWall app."

**Card 4: What Happens Next?**
- "Once you've set your NoteWall image as your wallpaper, come back to the app. We'll go back to the shortcut installation step. This time, when you tap on 'Wallpaper' in the Shortcuts app, you'll see your NoteWall wallpaper in the list and you'll be able to tap on it!"
- "The shortcut will then work perfectly - every time you add, edit, or delete notes, your wallpaper will update automatically."

**Card 5: Ready? Let's Do This!**
- Call to action

---

## Success Criteria

Onboarding is considered complete when:

1. ✅ User has installed the shortcut successfully
2. ✅ User has added at least one note
3. ✅ User has configured wallpaper preferences (or accepted defaults)
4. ✅ Initial wallpaper has been generated
5. ✅ User has confirmed granting all three permissions
6. ✅ User has viewed the final overview
7. ✅ User has tapped "Start Using NoteWall"

The app sets `hasCompletedSetup = true` and `completedOnboardingVersion = 3` when onboarding completes.

---

## Troubleshooting Paths

### Path 1: Can't Select Wallpaper During Installation

**Symptom**: Empty or grayed-out wallpaper list in Shortcuts app

**Cause**: Using Apple's preset wallpaper

**Solution**: 
1. Follow "How-to-Fix" guide
2. Set red instruction wallpaper as lock screen
3. Retry shortcut installation
4. Should now see wallpaper in list and be able to select it

### Path 2: Safari Not Installed

**Symptom**: Safari check alert appears

**Solution**:
- Confirm Safari is installed, OR
- Download Safari from App Store

### Path 3: Permissions Not Granted

**Symptom**: Shortcut fails to save wallpapers later

**Solution**:
- User must grant all three permissions during Step 6
- If missed, can re-run shortcut and grant permissions when prompted
- May need to go to Settings > Shortcuts to grant folder access

---

## Key Takeaways for Users

1. **Photo-based wallpapers required**: Apple's preset wallpapers won't work with the shortcut
2. **Easy fix available**: 2-minute process to set photo-based wallpaper if needed
3. **Three permissions needed**: HomeScreen folder, LockScreen folder, and Notifications
4. **Notes appear on lock screen**: Any notes added will be overlaid on the wallpaper
5. **Automatic updates**: Wallpaper updates when notes change (via shortcut)

---

## Design Principles

1. **Progressive Disclosure**: Information revealed step-by-step, not overwhelming
2. **Visual + Text Options**: Both video and text versions for different learning preferences
3. **Clear Problem/Solution**: Explicitly explains limitations and solutions
4. **Celebratory Completion**: Transition animation and confetti for positive reinforcement
5. **Help Always Available**: Help button accessible from multiple steps
6. **Flexible Configuration**: Most settings have sensible defaults, customization optional

---

This documentation provides a complete, in-depth understanding of the NoteWall onboarding flow, covering every step, user action, configuration option, and educational resource provided to users during setup.

