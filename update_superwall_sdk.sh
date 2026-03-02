#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="$ROOT_DIR/NoteWall.xcodeproj"
SCHEME_NAME="NoteWall"
RESOLVED_PATH="$PROJECT_PATH/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"

for cmd in curl git python3 xcodebuild; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: missing required command '$cmd'"
    exit 1
  fi
done

if [[ ! -f "$RESOLVED_PATH" ]]; then
  echo "Error: Package.resolved not found at: $RESOLVED_PATH"
  exit 1
fi

echo "Fetching latest Superwall release..."
LATEST_TAG="$(curl -fsSL "https://api.github.com/repos/superwall/Superwall-iOS/releases/latest" | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')"

if [[ -z "$LATEST_TAG" ]]; then
  echo "Error: could not determine latest Superwall release tag"
  exit 1
fi

TAG_COMMIT="$(git ls-remote https://github.com/superwall/Superwall-iOS "refs/tags/${LATEST_TAG}^{}" | awk 'NR==1 {print $1}')"
if [[ -z "$TAG_COMMIT" ]]; then
  TAG_COMMIT="$(git ls-remote https://github.com/superwall/Superwall-iOS "refs/tags/${LATEST_TAG}" | awk 'NR==1 {print $1}')"
fi

if [[ -z "$TAG_COMMIT" ]]; then
  echo "Error: could not resolve commit for tag '$LATEST_TAG'"
  exit 1
fi

echo "Latest Superwall release: $LATEST_TAG ($TAG_COMMIT)"

python3 - "$RESOLVED_PATH" "$LATEST_TAG" "$TAG_COMMIT" <<'PY'
import json
import pathlib
import sys

resolved_path = pathlib.Path(sys.argv[1])
version = sys.argv[2]
revision = sys.argv[3]

data = json.loads(resolved_path.read_text())
updated = False

for pin in data.get("pins", []):
    if pin.get("identity") == "superwall-ios":
        state = pin.setdefault("state", {})
        if state.get("version") != version or state.get("revision") != revision:
            state["version"] = version
            state["revision"] = revision
            updated = True
        break
else:
    raise SystemExit("Error: 'superwall-ios' pin not found in Package.resolved")

resolved_path.write_text(json.dumps(data, indent=2) + "\n")
print("Updated" if updated else "No changes needed")
PY

echo "Validating package resolution from lockfile..."
xcodebuild -resolvePackageDependencies \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME_NAME" \
  -onlyUsePackageVersionsFromResolvedFile \
  >/tmp/superwall-update-resolve.log 2>&1

if grep -q "SuperwallKit: https://github.com/superwall/Superwall-iOS @" /tmp/superwall-update-resolve.log; then
  grep "SuperwallKit: https://github.com/superwall/Superwall-iOS @" /tmp/superwall-update-resolve.log | tail -n 1
fi

echo "Done. Superwall SDK is pinned to $LATEST_TAG."
