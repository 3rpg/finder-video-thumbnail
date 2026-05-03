#!/usr/bin/env bash
set -euo pipefail

FRAME_COUNT=20
START_SECONDS=5
OUTPUT_WIDTH=1920
OUTPUT_HEIGHT=1080
COLUMNS=5
ROWS=4
TILE_WIDTH=$((OUTPUT_WIDTH / COLUMNS))
TILE_HEIGHT=$((OUTPUT_HEIGHT / ROWS))
OUTPUT_SUBDIR="${FINDER_VIDEO_GRID_OUTPUT_SUBDIR:-${VIDEO_THUMBNAIL_OUTPUT_SUBDIR:-视频网格}}"

find_tool() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi

  for candidate in "/opt/homebrew/bin/$name" "/usr/local/bin/$name"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

notify() {
  local title="$1"
  local message="$2"
  /usr/bin/osascript -e "display notification \"${message//\"/\\\"}\" with title \"${title//\"/\\\"}\"" >/dev/null 2>&1 || true
}

die() {
  notify "视频网格生成失败" "$1"
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

unique_output_path() {
  local dir="$1"
  local name="$2"
  local candidate="$dir/${name}_grid_1080p.jpg"
  local counter=2

  while [[ -e "$candidate" ]]; do
    candidate="$dir/${name}_grid_1080p_${counter}.jpg"
    counter=$((counter + 1))
  done

  printf '%s\n' "$candidate"
}

format_duration() {
  awk -v duration="$1" '
    BEGIN {
      h = int(duration / 3600)
      m = int((duration % 3600) / 60)
      s = int(duration % 60)
      if (h > 0) {
        printf "%02d:%02d:%02d", h, m, s
      } else {
        printf "%02d:%02d", m, s
      }
    }
  '
}

format_size() {
  awk -v bytes="$1" '
    BEGIN {
      if (bytes >= 1073741824) {
        printf "%.2f GB", bytes / 1073741824
      } else {
        printf "%.1f MB", bytes / 1048576
      }
    }
  '
}

render_metadata_overlay() {
  local output="$1"
  local title="$2"
  local info="$3"
  local swift_cache
  swift_cache="$(dirname "$output")/swift-module-cache"
  mkdir -p "$swift_cache"

  /usr/bin/swift -module-cache-path "$swift_cache" - "$output" "$title" "$info" "$OUTPUT_WIDTH" "152" <<'SWIFT'
import AppKit

let args = CommandLine.arguments
guard args.count == 6,
      let width = Int(args[4]),
      let height = Int(args[5]) else {
  exit(2)
}

let output = args[1]
let title = args[2]
let info = args[3]
let size = NSSize(width: width, height: height)
let image = NSImage(size: size)

image.lockFocus()
NSColor(calibratedWhite: 0.0, alpha: 0.68).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

let paragraph = NSMutableParagraphStyle()
paragraph.lineBreakMode = .byTruncatingMiddle

let titleAttributes: [NSAttributedString.Key: Any] = [
  .font: NSFont.boldSystemFont(ofSize: 42),
  .foregroundColor: NSColor.white,
  .paragraphStyle: paragraph
]
let infoAttributes: [NSAttributedString.Key: Any] = [
  .font: NSFont.systemFont(ofSize: 32),
  .foregroundColor: NSColor(calibratedWhite: 0.90, alpha: 1.0),
  .paragraphStyle: paragraph
]

let left: CGFloat = 42
let usableWidth = CGFloat(width) - left * 2
(title as NSString).draw(in: NSRect(x: left, y: 76, width: usableWidth, height: 52), withAttributes: titleAttributes)
(info as NSString).draw(in: NSRect(x: left, y: 28, width: usableWidth, height: 40), withAttributes: infoAttributes)
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
  exit(3)
}

try png.write(to: URL(fileURLWithPath: output), options: .atomic)
SWIFT
}

FFMPEG="$(find_tool ffmpeg)" || die "找不到 ffmpeg。请先运行：brew install ffmpeg"
FFPROBE="$(find_tool ffprobe)" || die "找不到 ffprobe。请先运行：brew install ffmpeg"
[[ -x /usr/bin/swift ]] || die "找不到 /usr/bin/swift，无法绘制视频信息。请先安装 Apple Command Line Tools。"

if [[ "$#" -eq 0 ]]; then
  die "没有收到视频文件。请在访达中右键选择视频文件后运行快速操作。"
fi

make_sheet() {
  local input="$1"

  if [[ ! -f "$input" ]]; then
    printf 'Skip non-file input: %s\n' "$input" >&2
    return 0
  fi

  local duration
  duration="$("$FFPROBE" -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null || true)"
  if [[ -z "$duration" || "$duration" == "N/A" ]]; then
    printf 'Skip unreadable media: %s\n' "$input" >&2
    notify "视频网格生成失败" "无法读取视频时长：$(basename "$input")"
    return 1
  fi

  local dir output_dir base name output tmpdir
  dir="$(dirname "$input")"
  output_dir="$dir"
  if [[ -n "$OUTPUT_SUBDIR" ]]; then
    output_dir="$dir/$OUTPUT_SUBDIR"
    mkdir -p "$output_dir"
  fi
  base="$(basename "$input")"
  name="${base%.*}"
  output="$(unique_output_path "$output_dir" "$name")"
  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/video-contact-sheet.XXXXXX")"

  cleanup() {
    rm -rf "$tmpdir"
  }
  trap cleanup RETURN

  local timestamps
  timestamps="$(awk -v duration="$duration" -v start="$START_SECONDS" -v count="$FRAME_COUNT" '
    BEGIN {
      if (duration <= 0) exit 1
      actual_start = duration > start ? start : 0
      remaining = duration - actual_start
      printf "%.6f\n", actual_start
      for (i = 1; i < count; i++) {
        if (remaining <= 0) {
          t = actual_start
        } else {
          t = actual_start + remaining * i / count
        }
        if (t >= duration) t = duration > 0.2 ? duration - 0.2 : duration * 0.9
        if (t < 0) t = 0
        printf "%.6f\n", t
      }
    }
  ')" || {
    notify "视频网格生成失败" "无法计算抽帧时间点：$base"
    return 1
  }

  local width height fps size formatted_duration formatted_size overlay_file sheet_file title_line info_line
  width="$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null | head -n 1 || true)"
  height="$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null | head -n 1 || true)"
  fps="$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null | awk -F/ 'NF == 2 && $2 != 0 { printf "%.2f", $1 / $2; next } { print }' | head -n 1 || true)"
  size="$(stat -f '%z' "$input" 2>/dev/null || echo 0)"
  formatted_duration="$(format_duration "$duration")"
  formatted_size="$(format_size "$size")"
  title_line="$base"
  info_line="${formatted_duration}  |  ${width:-?}x${height:-?}  |  ${fps:-?} fps  |  ${formatted_size}"
  overlay_file="$tmpdir/metadata-overlay.png"
  sheet_file="$tmpdir/sheet.jpg"
  render_metadata_overlay "$overlay_file" "$title_line" "$info_line" || {
    notify "视频网格生成失败" "渲染视频信息失败：$base"
    return 1
  }

  local index=1
  while IFS= read -r timestamp; do
    "$FFMPEG" -hide_banner -loglevel error \
      -ss "$timestamp" \
      -i "$input" \
      -frames:v 1 \
      -vf "scale=${TILE_WIDTH}:${TILE_HEIGHT}:force_original_aspect_ratio=increase,crop=${TILE_WIDTH}:${TILE_HEIGHT}" \
      -q:v 2 \
      "$tmpdir/frame_$(printf '%03d' "$index").jpg" || {
        notify "视频网格生成失败" "抽帧失败：$base"
        return 1
      }
    index=$((index + 1))
  done <<< "$timestamps"

  "$FFMPEG" -hide_banner -loglevel error \
    -framerate 1 \
    -i "$tmpdir/frame_%03d.jpg" \
    -filter_complex "tile=${COLUMNS}x${ROWS}:margin=0:padding=0,scale=${OUTPUT_WIDTH}:${OUTPUT_HEIGHT}" \
    -frames:v 1 \
    -q:v 2 \
    -y "$sheet_file" || {
      notify "视频网格生成失败" "拼接图片失败：$base"
      return 1
    }

  "$FFMPEG" -hide_banner -loglevel error \
    -i "$sheet_file" \
    -i "$overlay_file" \
    -filter_complex "overlay=0:H-h" \
    -frames:v 1 \
    -q:v 2 \
    -y "$output" || {
      notify "视频网格生成失败" "合成视频信息失败：$base"
      return 1
    }

  notify "视频网格已生成" "$(basename "$output")"
  printf '%s\n' "$output"
}

status=0
for input in "$@"; do
  make_sheet "$input" || status=1
done

exit "$status"
