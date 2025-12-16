# NoteWall App - Complete Context & Issues Documentation

## 📱 App Overview

**NoteWall** is an iOS productivity app that displays user notes directly on their iPhone lock screen wallpaper. The app generates custom wallpapers with notes overlaid on them, allowing users to see their reminders and tasks every time they look at their phone.

### Core Functionality

1. **Note Management**: Users can create, edit, and delete notes/tasks
2. **Wallpaper Generation**: The app generates custom wallpapers with notes rendered on them
3. **Background Customization**: Users can choose:
   - Custom photos from their library
   - Preset colors (black, gray)
   - No background (transparent)
4. **Shortcut Integration**: Uses iOS Shortcuts to apply the generated wallpaper to the lock screen
5. **Photos Integration**: Saves generated wallpapers to Photos library (optional)

### Technical Stack

- **Language**: Swift
- **Framework**: SwiftUI
- **Platform**: iOS 16+
- **Key Dependencies**: 
  - Photos framework (for saving wallpapers)
  - Shortcuts integration via URL schemes
  - RevenueCat (for in-app purchases/paywall)

---

## 🎯 Current User Flow

### Onboarding Process (Current)

1. **Welcome Screen**: "Welcome to NoteWall" → User clicks "Continue"
2. **Install Shortcut**: 
   - Instructions to install the iOS Shortcut
   - Video guide (Picture-in-Picture)
   - User clicks "Next" after installing
3. **Add Notes**: User creates their first notes
4. **Choose Wallpapers**: 
   - User selects background image/color for lock screen
   - User selects home screen wallpaper (optional)
   - User indicates if they have lock screen widgets
5. **Allow Permissions**: Request Photos library permission
6. **Overview**: Preview of the generated wallpaper

### Post-Onboarding

- Users can add/edit/delete notes
- App generates new wallpaper when notes change
- Shortcut is triggered to apply the wallpaper
- Wallpapers are saved to Photos library (if permission granted)

---

## ❌ The Core Problem: Wallpaper Preset Selection

### The Issue

**iOS allows users to have multiple wallpaper "presets" or "sets"** (introduced in iOS 16+). Each preset can be:
- **Apple preset wallpapers** (built-in, not selectable in Shortcuts)
- **Custom photo-based wallpapers** (selectable in Shortcuts)

**The Problem:**
1. The iOS Shortcut needs to know **which preset number** to update (preset #1, #2, #3, etc.)
2. Users must **manually configure** the shortcut after installation to select which preset to update
3. If a user's current wallpaper is an **Apple preset**, they **cannot select it** in the Shortcuts app
4. This creates **friction and confusion**, especially for:
   - Users who don't know if they have Apple or custom wallpapers
   - Users with multiple presets who don't know which number to select
   - Older users who find the process complicated

### Current Shortcut Configuration

The shortcut is shared via iCloud link: `https://www.icloud.com/shortcuts/37aa5bd3a1274af1b502c8eeda60fbf7`

**Current Flow:**
1. User installs shortcut from iCloud link
2. User must manually open Shortcuts app
3. User clicks on the shortcut → "Set Wallpaper" action
4. User must click on the wallpaper parameter
5. User must select their current wallpaper from a list
6. **PROBLEM**: If current wallpaper is Apple preset, it's not in the list → user is stuck

### Technical Constraints

**What iOS DOES NOT allow:**
- ❌ No API to detect current wallpaper type (Apple preset vs custom)
- ❌ No API to count wallpaper presets
- ❌ No API to detect which preset number is active
- ❌ No API to programmatically create wallpaper presets
- ❌ No API to modify Shortcuts from within an app
- ❌ Cannot deep-link to Settings → Wallpaper (can only open Settings app)

**What iOS DOES allow:**
- ✅ Can open Settings app (`UIApplication.openSettingsURLString`)
- ✅ Can save images to Photos library
- ✅ Can launch shortcuts via URL scheme (`shortcuts://run-shortcut?name=...`)
- ✅ Shortcuts can read files from shared folders (iCloud Drive, app groups)

---

## 💡 Proposed Solutions

### Solution 1: Ask User for Preset Count (RECOMMENDED)

**Flow:**
1. User selects background image/color in app
2. App saves wallpaper to Photos library
3. **New Step**: Guide user to edit their current wallpaper preset to use the NoteWall image
   - Provide "Open Settings" button (opens Settings app)
   - Clear instructions: "Go to Settings → Wallpaper → Edit your current preset → Choose the NoteWall image from Photos"
4. **New Step**: Ask user: "Which preset number are you currently using?" (1, 2, 3, ... up to 20)
5. Based on their answer, provide the corresponding shortcut link
   - If they have 2 presets total, new one is #3 → give them shortcut version #3
   - If they have 5 presets total, new one is #6 → give them shortcut version #6

**Pros:**
- ✅ Accurate (no guessing)
- ✅ Simple (one question)
- ✅ Reliable (works for all users)
- ✅ Low friction (counting presets is easy)

**Cons:**
- ⚠️ Requires maintaining multiple shortcut versions (one for each preset number 1-20)
- ⚠️ Adds one step to onboarding

**Implementation Notes:**
- Need to create 20 different shortcut versions (preset #1 through #20)
- Each shortcut is pre-configured to update that specific preset number
- Store user's preset number in app storage for future reference

### Solution 2: Edit Current Preset (Alternative)

**Flow:**
1. User selects background image/color in app
2. App saves wallpaper to Photos library
3. Guide user to **edit their current preset** (not create new)
   - "Open Settings" button
   - Instructions to edit current wallpaper preset
4. Ask: "What preset number is your current wallpaper?" (1, 2, 3, etc.)
5. Provide shortcut link for that preset number

**Pros:**
- ✅ Simpler (no need to create new preset)
- ✅ User knows which preset they're using
- ✅ Less steps overall

**Cons:**
- ⚠️ User changes their current wallpaper (may not want that)
- ⚠️ Still requires asking for preset number

### Solution 3: Smart Default (Fallback)

**Flow:**
1. Assume most users have 1-3 presets
2. Default to preset #3 (covers most cases)
3. Provide shortcut version #3 by default
4. Add setting in app: "If shortcut doesn't work, try preset #2 or #4"
5. User can change preset number in settings if needed

**Pros:**
- ✅ No user input needed initially
- ✅ Works for majority of users

**Cons:**
- ⚠️ May be wrong for users with many presets
- ⚠️ Requires troubleshooting if wrong

---

## 🎯 Recommended Implementation

### Hybrid Approach (Best of Both Worlds)

**Primary Flow:**
1. User selects background image/color
2. App saves to Photos library
3. Show screen: "Set this as your wallpaper"
   - Button: "Open Settings" (opens Settings app)
   - Instructions: "Go to Settings → Wallpaper → Edit your current preset → Choose the NoteWall image from Photos"
4. After user returns from Settings, ask: "Which preset number are you currently using?"
   - Show picker: 1, 2, 3, ... up to 20
   - Helper text: "This is the preset you just edited. Check Settings → Wallpaper if unsure."
5. Store preset number in `@AppStorage`
6. Provide shortcut link based on preset number
   - Use function: `getShortcutURL(for presetNumber: Int) -> String`
   - Returns corresponding iCloud shortcut link

**Fallback:**
- If user skips or doesn't know, default to preset #3
- Add setting in app to change preset number later

### Code Structure Needed

```swift
// State variable
@AppStorage("wallpaperPresetNumber") private var wallpaperPresetNumber: Int = 3

// Function to get shortcut URL
private func getShortcutURL(for presetNumber: Int) -> String {
    // Map preset numbers to shortcut URLs
    let shortcutURLs: [Int: String] = [
        1: "https://www.icloud.com/shortcuts/[preset1-url]",
        2: "https://www.icloud.com/shortcuts/[preset2-url]",
        3: "https://www.icloud.com/shortcuts/[preset3-url]",
        // ... up to 20
    ]
    return shortcutURLs[presetNumber] ?? shortcutURLs[3]! // Default to #3
}
```

---

## 🔧 Technical Implementation Details

### Onboarding Flow Updates Needed

1. **New State Variable:**
   ```swift
   @AppStorage("wallpaperPresetNumber") private var wallpaperPresetNumber: Int = 3
   @State private var showPresetNumberPicker = false
   ```

2. **New Onboarding Step** (after "Choose Wallpapers"):
   - Screen with "Open Settings" button
   - Instructions for editing wallpaper preset
   - After return, show preset number picker

3. **Update Shortcut Installation:**
   - Use `getShortcutURL(for: wallpaperPresetNumber)` instead of hardcoded URL
   - Update instructions to remove "select current wallpaper" step

### Settings Integration

Add to Settings view:
- Option to change wallpaper preset number
- Helper text explaining what it does
- Link to re-run shortcut setup if needed

---

## 📋 Questions for Development

1. **Shortcut Versions**: Do you have 20 different shortcut versions ready, or do they need to be created? What's the pattern for their URLs?

2. **User Experience**: Should we:
   - Create new preset (Solution 1)?
   - Edit current preset (Solution 2)?
   - Or offer both options?

3. **Fallback Behavior**: What should happen if:
   - User doesn't know their preset number?
   - User has more than 20 presets?
   - User skips the preset selection step?

4. **Settings Deep Link**: Should we try to open Settings app automatically, or just provide instructions?

5. **Validation**: Should we validate that the user actually edited their wallpaper before proceeding?

---

## 🚀 Success Criteria

The solution should:
- ✅ Work for users with Apple preset wallpapers
- ✅ Work for users with custom photo wallpapers
- ✅ Work for users with 1 preset or 20+ presets
- ✅ Minimize friction (ideally 1-2 simple steps)
- ✅ Be clear and understandable for non-technical users
- ✅ Handle edge cases gracefully

---

## 📝 Additional Context

### Current Onboarding Steps (from code)

```swift
enum OnboardingPage {
    case welcome
    case installShortcut
    case addNotes
    case chooseWallpapers
    case allowPermissions
    case overview
}
```

### Current Shortcut URL

```swift
private let shortcutURL = "https://www.icloud.com/shortcuts/37aa5bd3a1274af1b502c8eeda60fbf7"
```

### Key Files

- `OnboardingView.swift` - Main onboarding flow
- `ContentView.swift` - Main app interface
- `HomeScreenImageManager.swift` - Handles wallpaper file storage
- `PhotoSaver.swift` - Handles saving to Photos library
- `ShortcutSetupView.swift` - Shortcut installation UI

---

## 🎯 Next Steps

1. **Decide on approach**: Solution 1 (create new) vs Solution 2 (edit current)
2. **Create shortcut versions**: Prepare 20 shortcut versions (preset #1 through #20)
3. **Implement UI**: Add preset number selection to onboarding
4. **Update instructions**: Remove confusing "select current wallpaper" step
5. **Test thoroughly**: Test with users who have 1, 2, 5, 10+ presets
6. **Add fallback**: Handle edge cases and user errors gracefully

---

## 💬 Summary

The main challenge is that **iOS doesn't provide APIs to detect wallpaper preset information**, so we must ask the user. The recommended solution is to:

1. Guide users to set up their wallpaper preset (either create new or edit current)
2. Ask them which preset number they're using
3. Provide the correct shortcut link based on that number

This balances **accuracy** (we get the right preset number) with **simplicity** (just one question) and **reliability** (works for all users).






