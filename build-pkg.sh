#!/usr/bin/env bash
set -euo pipefail
export COPYFILE_DISABLE=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD_DIR="$ROOT/build/pkg"
PKG_ROOT="$BUILD_DIR/root"
PKG_SCRIPTS="$BUILD_DIR/scripts"
WORKFLOW_NAME="生成视频网格.workflow"
WORKFLOW_SOURCE="$ROOT/$WORKFLOW_NAME"
WORKFLOW_TARGET="$PKG_ROOT/Library/Services/$WORKFLOW_NAME"
COMPONENT_PKG="$BUILD_DIR/finder-video-grid-component.pkg"
OUTPUT_PKG="$ROOT/releases/finder-video-grid-$VERSION.pkg"

if [[ ! -d "$WORKFLOW_SOURCE" ]]; then
  echo "Missing workflow: $WORKFLOW_SOURCE" >&2
  exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$PKG_ROOT/Library/Services" "$PKG_SCRIPTS" "$ROOT/releases"

cp -R "$WORKFLOW_SOURCE" "$WORKFLOW_TARGET"
cp "$ROOT/create-video-contact-sheet.sh" "$WORKFLOW_TARGET/Contents/Resources/create-video-contact-sheet.sh"
chmod +x "$WORKFLOW_TARGET/Contents/Resources/create-video-contact-sheet.sh"
/usr/bin/xattr -cr "$WORKFLOW_TARGET" >/dev/null 2>&1 || true
/usr/bin/dot_clean -m "$PKG_ROOT" >/dev/null 2>&1 || true
/usr/bin/find "$PKG_ROOT" -name '._*' -delete

/usr/libexec/PlistBuddy \
  -c 'Set :actions:0:action:ActionParameters:COMMAND_STRING "/Library/Services/生成视频网格.workflow/Contents/Resources/create-video-contact-sheet.sh" "$@"' \
  "$WORKFLOW_TARGET/Contents/document.wflow"

cat > "$PKG_SCRIPTS/postinstall" <<'POSTINSTALL'
#!/bin/sh
set -eu

WORKFLOW="/Library/Services/生成视频网格.workflow"

if [ -d "$WORKFLOW" ]; then
  /usr/bin/xattr -cr "$WORKFLOW" >/dev/null 2>&1 || true
  /bin/chmod +x "$WORKFLOW/Contents/Resources/create-video-contact-sheet.sh" >/dev/null 2>&1 || true
fi

CONSOLE_USER="$(/usr/bin/stat -f %Su /dev/console 2>/dev/null || true)"
if [ -n "$CONSOLE_USER" ] && [ "$CONSOLE_USER" != "root" ]; then
  USER_HOME="$(/usr/bin/dscl . -read "/Users/$CONSOLE_USER" NFSHomeDirectory 2>/dev/null | /usr/bin/awk '{print $2}')"
  PBS_PLIST="$USER_HOME/Library/Preferences/pbs.plist"
  SERVICE_KEY="(null) - 生成视频网格 - runWorkflowAsService"
  BUNDLE_KEY="com.codex.video-grid.workflow - 生成视频网格 - runWorkflowAsService"

  /bin/mkdir -p "$USER_HOME/Library/Preferences"
  /usr/libexec/PlistBuddy -c "Delete :NSServicesStatus:$SERVICE_KEY" "$PBS_PLIST" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Delete :NSServicesStatus:$BUNDLE_KEY" "$PBS_PLIST" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :NSServicesStatus dict" "$PBS_PLIST" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :NSServicesStatus:$SERVICE_KEY dict" "$PBS_PLIST" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :NSServicesStatus:$SERVICE_KEY:presentation_modes dict" "$PBS_PLIST" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :NSServicesStatus:$SERVICE_KEY:presentation_modes:ContextMenu bool true" "$PBS_PLIST" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :NSServicesStatus:$SERVICE_KEY:presentation_modes:FinderPreview bool true" "$PBS_PLIST" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :NSServicesStatus:$SERVICE_KEY:presentation_modes:ServicesMenu bool true" "$PBS_PLIST" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :NSServicesStatus:$SERVICE_KEY:presentation_modes:TouchBar bool false" "$PBS_PLIST" >/dev/null 2>&1 || true
  /usr/sbin/chown "$CONSOLE_USER" "$PBS_PLIST" >/dev/null 2>&1 || true
fi

/System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true
/usr/bin/killall cfprefsd >/dev/null 2>&1 || true
/usr/bin/killall Finder >/dev/null 2>&1 || true

exit 0
POSTINSTALL
chmod +x "$PKG_SCRIPTS/postinstall"

/usr/bin/pkgbuild \
  --root "$PKG_ROOT" \
  --scripts "$PKG_SCRIPTS" \
  --identifier "com.codex.finder-video-grid" \
  --version "$VERSION" \
  --install-location "/" \
  --filter '(^|/)\.DS_Store$' \
  --filter '(^|/)CVS($|/)' \
  --filter '(^|/)\.svn($|/)' \
  --filter '(^|/)\._.*' \
  "$COMPONENT_PKG"

/usr/bin/productbuild \
  --package "$COMPONENT_PKG" \
  "$OUTPUT_PKG"

echo "$OUTPUT_PKG"
