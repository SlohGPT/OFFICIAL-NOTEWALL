# NoteWall iOS App

A minimal iOS app that converts text notes into black wallpaper images with white centered text.

## Setup Instructions

### 1. Open in Xcode

1. Open `NoteWall.xcodeproj` in Xcode
2. Wait for Xcode to index the project

### 2. Configure Signing

1. Select the **NoteWall** target in the project navigator
2. Go to **Signing & Capabilities** tab
3. Select your **Team** from the dropdown
4. Xcode will automatically generate a bundle identifier

### 3. Run on Device

#### Option A: Physical iPhone
1. Connect your iPhone via USB
2. Trust the computer on your iPhone if prompted
3. Select your iPhone from the device dropdown in Xcode
4. Click the **Run** button (▶️) or press `Cmd + R`

#### Option B: iPhone Simulator
1. Select any iPhone simulator from the device dropdown
2. Click the **Run** button (▶️) or press `Cmd + R`

### 4. First Launch Setup

1. When the app launches, you'll see the onboarding popup
2. Tap "Install Shortcut" to open the Shortcuts app
3. Install the "Set NoteWall Wallpaper" shortcut
4. Return to NoteWall app

## Usage

### Adding Notes
- Type in the "Add a note..." field at the bottom
- Tap the **+** button or press return

### Editing Notes
- Tap any note to edit it inline
- Changes save automatically

### Deleting Notes
- Swipe left on any note to delete it

### Generating Wallpaper
1. Add your notes
2. Tap **Update Wallpaper** button
3. The app will generate a 1290×2796 black image with white centered text
4. Image saves to Photos library
5. Shortcuts app opens automatically to set as wallpaper

### Settings
- Tap the **Settings** icon in bottom navigation
- View app info
- Delete all notes (with confirmation)
- Reinstall shortcut if needed

## Project Structure

```
NoteWall/
├── NoteWallApp.swift        # App entry point
├── Models.swift              # Note data model
├── ContentView.swift         # Homepage with notes list
├── MainTabView.swift         # Bottom navigation
├── OnboardingView.swift      # First launch popup
├── SettingsView.swift        # Settings page
├── WallpaperRenderer.swift   # Image generation
├── PhotoSaver.swift          # Photos library integration
├── Info.plist                # App configuration
└── Assets.xcassets/          # App icons and assets
```

## Requirements

- iOS 15.0 or later
- Xcode 15.0 or later
- iPhone (app is iPhone-only, portrait orientation)

## Troubleshooting

### "No signing certificate found"
- Go to Xcode Preferences → Accounts
- Add your Apple ID
- Select your team in Signing & Capabilities

### "Untrusted Developer" on device
- Go to Settings → General → VPN & Device Management
- Trust your developer certificate

### Photos permission not working
- Check that Info.plist has `NSPhotoLibraryAddUsageDescription`
- Reset permissions: Settings → NoteWall → Photos

### Shortcuts integration not working
- Ensure shortcut is installed: https://www.icloud.com/shortcuts/9ad9e11424104d2eb14e922abd3b9620
- Check shortcut name matches exactly: "Set NoteWall Wallpaper"

### Pushing commits to GitHub
- See `GIT_PUSH_GUIDE.md` for a step-by-step walkthrough (including certificate fixes and permission requests) to push from Cursor to the GitHub remote.

## Features

✅ Multiple notes creation/editing/deletion
✅ Onboarding with shortcut installation
✅ Bottom navigation (Home + Settings)
✅ Wallpaper generation (1290×2796 black with white text)
✅ Photos library integration
✅ Shortcuts app integration
✅ Settings page with app info
✅ Delete all notes with confirmation

## Version

1.0 - Initial MVP release
