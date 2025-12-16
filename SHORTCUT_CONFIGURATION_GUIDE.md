# NoteWall Shortcut Configuration Guide

## The Problem

When the shortcut is shared via iCloud link, folder references become **variables** instead of **hardcoded paths**. This means:
- Users must manually select folders every time they install/reinstall
- After app reinstall, shortcuts fail until folders are manually reconfigured
- This creates friction in the onboarding flow

## The Solution: Pre-Configure Folder Paths

### Step 1: Configure the Shortcut BEFORE Sharing

1. **Open Shortcuts App** on your iPhone
2. **Edit the "Set Notewall Wallpaper" shortcut**
3. **For "Get contents of HomeScreen" action:**
   - Tap on the blue "HomeScreen" text (the variable)
   - Select "Choose" or tap the folder icon
   - Navigate to: `Files → On My iPhone → NoteWall → HomeScreen`
   - Select the folder
   - When prompted, tap **"Always Allow"**
   - The folder path should now be hardcoded (not blue/variable)

4. **For "Get contents of LockScreen" action:**
   - Repeat the same process
   - Navigate to: `Files → On My iPhone → NoteWall → LockScreen`
   - Select the folder
   - Tap **"Always Allow"**

5. **Verify the configuration:**
   - The folder names should NOT be blue/tappable anymore
   - They should show the actual folder path
   - Save the shortcut

### Step 2: Share the Pre-Configured Shortcut

1. **Share the shortcut** via iCloud link
2. **Test it** on a fresh device to ensure it works without manual folder selection
3. **Update the shortcut URL** in your app code if needed

## Why This Works

- **Hardcoded paths** persist when shortcuts are shared
- Users only need to tap "Allow" on permission dialogs (no navigation required)
- The shortcut automatically finds the folders at the configured paths

## Current Onboarding Flow

The updated onboarding now includes:
1. Clear instructions about folder navigation
2. Step-by-step guidance on what to expect
3. Visual indicators showing the exact path users need to navigate to

## Testing Checklist

- [ ] Shortcut works on fresh install without manual folder selection
- [ ] Permission dialogs appear (user just taps "Allow")
- [ ] No file picker navigation required
- [ ] Works after app reinstall
- [ ] Works after shortcut reinstall

## If Users Still Have Issues

If users report needing to manually select folders:
1. They may have an old version of the shortcut
2. The shortcut may not have been properly pre-configured
3. iOS may have reset permissions (rare)

**Solution:** Provide clear troubleshooting steps in the app's help section.





