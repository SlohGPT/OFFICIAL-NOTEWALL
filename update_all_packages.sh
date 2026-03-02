#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="$ROOT_DIR/NoteWall.xcodeproj"
SCHEME_NAME="NoteWall"
RESOLVED_PATH="$PROJECT_PATH/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"

for cmd in python3 xcodebuild git; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: missing required command '$cmd'"
    exit 1
  fi
done

if [[ ! -f "$RESOLVED_PATH" ]]; then
  echo "Error: Package.resolved not found at: $RESOLVED_PATH"
  exit 1
fi

BEFORE_JSON="$(mktemp)"
AFTER_JSON="$(mktemp)"
BACKUP_RESOLVED="$(mktemp)"

cp "$RESOLVED_PATH" "$BACKUP_RESOLVED"

python3 - "$RESOLVED_PATH" "$BEFORE_JSON" <<'PY'
import json
import pathlib
import sys

resolved = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
data = json.loads(resolved.read_text())

versions = {
    pin["identity"]: {
        "version": pin.get("state", {}).get("version", ""),
        "revision": pin.get("state", {}).get("revision", ""),
    }
    for pin in data.get("pins", [])
}

out.write_text(json.dumps(versions, sort_keys=True))
PY

restore_on_fail() {
  if [[ ! -f "$RESOLVED_PATH" ]]; then
    cp "$BACKUP_RESOLVED" "$RESOLVED_PATH"
  fi
}

trap restore_on_fail ERR

echo "Updating all Swift packages to latest allowed versions..."
rm -f "$RESOLVED_PATH"

xcodebuild -resolvePackageDependencies \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME_NAME" \
  -disablePackageRepositoryCache \
  >/tmp/all-packages-update.log 2>&1

if [[ ! -f "$RESOLVED_PATH" ]]; then
  echo "Error: Package.resolved was not regenerated"
  exit 1
fi

python3 - "$RESOLVED_PATH" "$AFTER_JSON" <<'PY'
import json
import pathlib
import sys

resolved = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
data = json.loads(resolved.read_text())

versions = {
    pin["identity"]: {
        "version": pin.get("state", {}).get("version", ""),
        "revision": pin.get("state", {}).get("revision", ""),
    }
    for pin in data.get("pins", [])
}

out.write_text(json.dumps(versions, sort_keys=True))
PY

python3 - "$BEFORE_JSON" "$AFTER_JSON" <<'PY'
import json
import sys

before = json.loads(open(sys.argv[1]).read())
after = json.loads(open(sys.argv[2]).read())

all_keys = sorted(set(before) | set(after))
changes = []

for key in all_keys:
    b = before.get(key, {})
    a = after.get(key, {})
    b_ver = b.get("version", "")
    a_ver = a.get("version", "")
    if b_ver != a_ver:
        changes.append((key, b_ver or "(none)", a_ver or "(none)"))

if not changes:
    print("No package version changes.")
else:
    print("Updated packages:")
    for identity, old, new in changes:
        print(f"- {identity}: {old} -> {new}")
PY

echo "Done. Updated lockfile: $RESOLVED_PATH"
