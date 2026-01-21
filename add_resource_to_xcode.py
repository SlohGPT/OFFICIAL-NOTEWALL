#!/usr/bin/env python3
import uuid
import re
import sys

def add_resource_to_xcode_project(project_file_path, file_name, file_type="text.xml"):
    """Add a resource file to an Xcode project"""
    
    # Read the project file
    try:
        with open(project_file_path, 'r') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"❌ Error: Could not find project file at {project_file_path}")
        return False
    
    # Generate unique IDs
    file_ref_id = str(uuid.uuid4()).replace('-', '').upper()[:24]
    build_file_id = str(uuid.uuid4()).replace('-', '').upper()[:24]
    
    print(f"📝 Adding {file_name} to Xcode project...")
    print(f"   File Reference ID: {file_ref_id}")
    print(f"   Build File ID: {build_file_id}")
    
    # Step 1: Add to PBXFileReference section
    # Matches typical pbxproj section header format
    file_ref_pattern = r'(/\* Begin PBXFileReference section \*/\s*)(.*?)(\s*/\* End PBXFileReference section \*/)'
    file_ref_match = re.search(file_ref_pattern, content, re.DOTALL)
    
    if not file_ref_match:
        print("❌ Could not find PBXFileReference section")
        return False
    
    file_ref_entry = f'\t\t{file_ref_id} /* {file_name} */ = {{isa = PBXFileReference; lastKnownFileType = {file_type}; path = {file_name}; sourceTree = "<group>"; }};\n'
    
    content = (
        content[:file_ref_match.end(2)] +
        file_ref_entry +
        content[file_ref_match.end(2):]
    )
    
    print("   ✅ Added to PBXFileReference section")
    
    # Step 2: Add to PBXBuildFile section
    build_file_pattern = r'(/\* Begin PBXBuildFile section \*/\s*)(.*?)(\s*/\* End PBXBuildFile section \*/)'
    build_file_match = re.search(build_file_pattern, content, re.DOTALL)
    
    if not build_file_match:
        print("❌ Could not find PBXBuildFile section")
        return False
    
    build_file_entry = f'\t\t{build_file_id} /* {file_name} in Resources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {file_name} */; }};\n'
    
    content = (
        content[:build_file_match.end(2)] +
        build_file_entry +
        content[build_file_match.end(2):]
    )
    
    print("   ✅ Added to PBXBuildFile section")
    
    # Step 3: Add to NoteWall group children
    # Find the main group for NoteWall using known ID
    group_pattern = r'(A5000002000000000000001)\s*/\* NoteWall \*/\s*=\s*\{.*?children\s*=\s*\((.*?)\);'
    group_match = re.search(group_pattern, content, re.DOTALL)
    
    if not group_match:
        print("❌ Could not find NoteWall group")
        return False
    
    children_content = group_match.group(2)
    children_entry = f'\n\t\t\t\t{file_ref_id} /* {file_name} */,'
    
    content = (
        content[:group_match.start(2)] +
        children_content + children_entry +
        content[group_match.end(2):]
    )
    
    print("   ✅ Added to NoteWall group")
    
    # Step 4: Add to PBXResourcesBuildPhase
    resources_pattern = r'(isa = PBXResourcesBuildPhase;[^}]*?files = \()(.*?)(\);)'
    resources_match = re.search(resources_pattern, content, re.DOTALL)
    
    if not resources_match:
        print("❌ Could not find PBXResourcesBuildPhase section")
        return False
    
    resources_entry = f'\n\t\t\t\t{build_file_id} /* {file_name} in Resources */,'
    
    content = (
        content[:resources_match.end(2)] +
        resources_entry +
        content[resources_match.end(2):]
    )
    
    print("   ✅ Added to PBXResourcesBuildPhase")
    
    # Write back to file
    try:
        with open(project_file_path, 'w') as f:
            f.write(content)
        print(f"\n✅ Successfully added {file_name} to Xcode project!")
        return True
    except Exception as e:
        print(f"❌ Error writing to project file: {e}")
        return False

if __name__ == "__main__":
    project_file = "NoteWall.xcodeproj/project.pbxproj"
    resource_file = "PrivacyInfo.xcprivacy"
    
    success = add_resource_to_xcode_project(project_file, resource_file)
    sys.exit(0 if success else 1)
