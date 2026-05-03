#!/usr/bin/env bash
set -euo pipefail

WORKFLOW_TARGET="$HOME/Library/Services/生成视频网格.workflow"
SYSTEM_WORKFLOW_TARGET="/Library/Services/生成视频网格.workflow"
SCRIPT_DIR="$HOME/Library/Application Scripts/com.codex.video-grid"
LEGACY_WORKFLOW_CN="$HOME/Library/Services/生成视频缩略图.workflow"
LEGACY_WORKFLOW="$HOME/Library/Services/Generate Video Thumbnail.workflow"
LEGACY_SCRIPT_DIR="$HOME/Library/Application Scripts/com.codex.video-thumbnail"

rm -rf "$WORKFLOW_TARGET"
if [[ -w "$(dirname "$SYSTEM_WORKFLOW_TARGET")" ]]; then
  rm -rf "$SYSTEM_WORKFLOW_TARGET"
else
  echo "System workflow may require admin removal:"
  echo "sudo rm -rf '$SYSTEM_WORKFLOW_TARGET'"
fi
rm -rf "$LEGACY_WORKFLOW_CN"
rm -rf "$LEGACY_WORKFLOW"
rm -rf "$SCRIPT_DIR"
rm -rf "$LEGACY_SCRIPT_DIR"

/usr/libexec/PlistBuddy -c 'Delete :NSServicesStatus:(null)\ -\ 生成视频网格\ -\ runWorkflowAsService' "$HOME/Library/Preferences/pbs.plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c 'Delete :NSServicesStatus:com.codex.video-grid.workflow\ -\ 生成视频网格\ -\ runWorkflowAsService' "$HOME/Library/Preferences/pbs.plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c 'Delete :NSServicesStatus:(null)\ -\ 生成视频缩略图\ -\ runWorkflowAsService' "$HOME/Library/Preferences/pbs.plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c 'Delete :NSServicesStatus:(null)\ -\ Generate\ Video\ Thumbnail\ -\ runWorkflowAsService' "$HOME/Library/Preferences/pbs.plist" >/dev/null 2>&1 || true

/System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true
killall Finder >/dev/null 2>&1 || true

echo "Uninstalled Finder Video Grid:"
echo "$WORKFLOW_TARGET"
