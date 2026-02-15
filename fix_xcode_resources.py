#!/usr/bin/env python3
"""
Fix Xcode project issue where individual asset catalog files are incorrectly
added to the Resources build phase, causing "Multiple commands produce" errors.
"""

import re
import sys

def fix_xcode_project(pbxproj_path):
    """Remove individual asset catalog file references from Resources build phase."""
    
    with open(pbxproj_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Find all PBXBuildFile references that include Contents.json or asset catalog images
    # These are the IDs we want to remove from the Resources build phase
    ids_to_remove = set()
    
    # Pattern to find PBXBuildFile entries for Contents.json and asset files
    # Format: <UUID> /* Contents.json in Resources */ = {isa = PBXBuildFile; fileRef = <UUID> /* Contents.json */; };
    buildfile_pattern = r'(\w+)\s+/\*\s+Contents\.json in Resources\s+\*/\s+=\s+\{isa\s+=\s+PBXBuildFile;'
    
    for match in re.finditer(buildfile_pattern, content):
        ids_to_remove.add(match.group(1))
    
    # Also look for individual icon and image files that should be in the asset catalog
    asset_file_patterns = [
        r'(\w+)\s+/\*\s+Icon-App-\S+\.png in Resources\s+\*/',
        r'(\w+)\s+/\*\s+mockup.*\.png in Resources\s+\*/',
        r'(\w+)\s+/\*\s+experiment-icon\.png in Resources\s+\*/',
        r'(\w+)\s+/\*\s+FAITHWALL\.png in Resources\s+\*/',
        r'(\w+)\s+/\*\s+skipForward3s\.png in Resources\s+\*/',
        r'(\w+)\s+/\*\s+skipBackward3s\.png in Resources\s+\*/',
        r'(\w+)\s+/\*\s+safari-logo.*\.png in Resources\s+\*/',
        r'(\w+)\s+/\*\s+shortcuts-app-logo\.png in Resources\s+\*/',
        r'(\w+)\s+/\*\s+stuck-placeholder\.png in Resources\s+\*/',
        r'(\w+)\s+/\*\s+notificationes\.png in Resources\s+\*/',
        r'(\w+)\s+/\*\s+image-\d-review\.png in Resources\s+\*/',
        r'(\w+)\s+/\*\s+logo-icon\.png in Resources\s+\*/',
        r'(\w+)\s+/\*\s+instruction_wallpaper\.png in Resources\s+\*/',
        r'(\w+)\s+/\*\s+arrow\.png in Resources\s+\*/',
    ]
    
    for pattern in asset_file_patterns:
        for match in re.finditer(pattern, content):
            ids_to_remove.add(match.group(1))
    
    print(f"Found {len(ids_to_remove)} asset catalog file references to remove")
    
    # Now remove these IDs from the PBXResourcesBuildPhase section
    # Find the Resources build phase section
    resources_section_pattern = r'(\/\* Begin PBXResourcesBuildPhase section \*\/.*?)(files = \()(.*?)(\);)(.*?\/\* End PBXResourcesBuildPhase section \*\/)'
    
    def remove_ids_from_files(match):
        before = match.group(1)
        files_start = match.group(2)
        files_content = match.group(3)
        files_end = match.group(4)
        after = match.group(5)
        
        # Split files into lines
        lines = files_content.split('\n')
        kept_lines = []
        removed_count = 0
        
        for line in lines:
            # Check if this line contains any of the IDs we want to remove
            should_remove = False
            for id_to_remove in ids_to_remove:
                if id_to_remove in line and 'in Resources' in line:
                    should_remove = True
                    removed_count += 1
                    break
            
            if not should_remove:
                kept_lines.append(line)
        
        print(f"Removed {removed_count} entries from Resources build phase")
        
        # Reconstruct the section
        new_files_content = '\n'.join(kept_lines)
        return before + files_start + new_files_content + files_end + after
    
    # Apply the replacement
    content = re.sub(
        resources_section_pattern,
        remove_ids_from_files,
        content,
        flags=re.DOTALL
    )
    
    if content == original_content:
        print("No changes were made - this might mean the pattern didn't match")
        return False
    
    # Write back
    with open(pbxproj_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Successfully updated {pbxproj_path}")
    return True

if __name__ == '__main__':
    pbxproj_path = '/Users/carly/GITHUB REPOS/STRANKY:APLIKACIE/NOTEWALL-CLAUDECODE/NoteWall.xcodeproj/project.pbxproj'
    
    print("Fixing Xcode project resource conflicts...")
    print(f"Project file: {pbxproj_path}")
    print()
    
    success = fix_xcode_project(pbxproj_path)
    
    if success:
        print()
        print("✅ Fix complete!")
        print("Please clean your build folder and rebuild:")
        print("  Product > Clean Build Folder (Shift+Cmd+K)")
        print("  Then build again")
    else:
        print("❌ No changes made - please check the script")
        sys.exit(1)
