#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="1.1"
SCRIPT_SOURCE="$ROOT/create-video-contact-sheet.sh"
SCRIPT_TARGET="$HOME/Library/Application Scripts/com.codex.video-grid/create-video-contact-sheet.sh"
WORKFLOW_SOURCE="$ROOT/生成视频网格.workflow"
WORKFLOW_TARGET="$HOME/Library/Services/生成视频网格.workflow"
LEGACY_SCRIPT_DIR="$HOME/Library/Application Scripts/com.codex.video-thumbnail"
LEGACY_WORKFLOW_CN="$HOME/Library/Services/生成视频缩略图.workflow"
LEGACY_WORKFLOW_EN="$HOME/Library/Services/Generate Video Thumbnail.workflow"

if [[ ! -f "$SCRIPT_SOURCE" ]]; then
  echo "Missing script: $SCRIPT_SOURCE" >&2
  exit 1
fi

if [[ ! -d "$WORKFLOW_SOURCE" ]]; then
  echo "Missing workflow: $WORKFLOW_SOURCE" >&2
  exit 1
fi

mkdir -p "$(dirname "$SCRIPT_TARGET")"
mkdir -p "$HOME/Library/Services"

cp "$SCRIPT_SOURCE" "$SCRIPT_TARGET"
chmod +x "$SCRIPT_TARGET"

rm -rf "$LEGACY_WORKFLOW_EN"
rm -rf "$LEGACY_WORKFLOW_CN"
rm -rf "$WORKFLOW_TARGET"
cp -R "$WORKFLOW_SOURCE" "$WORKFLOW_TARGET"
xattr -cr "$WORKFLOW_TARGET" >/dev/null 2>&1 || true
rm -rf "$LEGACY_SCRIPT_DIR"

/usr/libexec/PlistBuddy -c 'Delete :NSServicesStatus:(null)\ -\ 生成视频缩略图\ -\ runWorkflowAsService' "$HOME/Library/Preferences/pbs.plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c 'Delete :NSServicesStatus:(null)\ -\ Generate\ Video\ Thumbnail\ -\ runWorkflowAsService' "$HOME/Library/Preferences/pbs.plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c 'Add :NSServicesStatus:(null)\ -\ 生成视频网格\ -\ runWorkflowAsService dict' "$HOME/Library/Preferences/pbs.plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c 'Add :NSServicesStatus:(null)\ -\ 生成视频网格\ -\ runWorkflowAsService:presentation_modes dict' "$HOME/Library/Preferences/pbs.plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c 'Set :NSServicesStatus:(null)\ -\ 生成视频网格\ -\ runWorkflowAsService:presentation_modes:ContextMenu 1' "$HOME/Library/Preferences/pbs.plist" >/dev/null 2>&1 || \
  /usr/libexec/PlistBuddy -c 'Add :NSServicesStatus:(null)\ -\ 生成视频网格\ -\ runWorkflowAsService:presentation_modes:ContextMenu integer 1' "$HOME/Library/Preferences/pbs.plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c 'Set :NSServicesStatus:(null)\ -\ 生成视频网格\ -\ runWorkflowAsService:presentation_modes:FinderPreview 1' "$HOME/Library/Preferences/pbs.plist" >/dev/null 2>&1 || \
  /usr/libexec/PlistBuddy -c 'Add :NSServicesStatus:(null)\ -\ 生成视频网格\ -\ runWorkflowAsService:presentation_modes:FinderPreview integer 1' "$HOME/Library/Preferences/pbs.plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c 'Set :NSServicesStatus:(null)\ -\ 生成视频网格\ -\ runWorkflowAsService:presentation_modes:ServicesMenu 1' "$HOME/Library/Preferences/pbs.plist" >/dev/null 2>&1 || \
  /usr/libexec/PlistBuddy -c 'Add :NSServicesStatus:(null)\ -\ 生成视频网格\ -\ runWorkflowAsService:presentation_modes:ServicesMenu integer 1' "$HOME/Library/Preferences/pbs.plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c 'Set :NSServicesStatus:(null)\ -\ 生成视频网格\ -\ runWorkflowAsService:presentation_modes:TouchBar 0' "$HOME/Library/Preferences/pbs.plist" >/dev/null 2>&1 || \
  /usr/libexec/PlistBuddy -c 'Add :NSServicesStatus:(null)\ -\ 生成视频网格\ -\ runWorkflowAsService:presentation_modes:TouchBar integer 0' "$HOME/Library/Preferences/pbs.plist" >/dev/null 2>&1 || true

/System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true
killall Finder >/dev/null 2>&1 || true

echo "Installed Finder Video Grid v$VERSION:"
echo "$WORKFLOW_TARGET"
echo
echo "Use it from Finder: right click a video file > Quick Actions > 生成视频网格"
