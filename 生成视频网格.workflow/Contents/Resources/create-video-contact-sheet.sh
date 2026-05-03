#!/usr/bin/env bash
set -euo pipefail

FRAME_COUNT=16
START_SECONDS=5
OUTPUT_WIDTH=1920
OUTPUT_HEIGHT=1080
COLUMNS=4
ROWS=4
HEADER_HEIGHT=150
PAGE_MARGIN=16
TILE_GAP=14
TILE_BORDER=2
TILE_WIDTH=$(((OUTPUT_WIDTH - PAGE_MARGIN * 2 - TILE_GAP * (COLUMNS - 1)) / COLUMNS))
TILE_HEIGHT=$(((OUTPUT_HEIGHT - HEADER_HEIGHT - PAGE_MARGIN - TILE_GAP * (ROWS - 1)) / ROWS))
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

format_timestamp() {
  awk -v duration="$1" '
    BEGIN {
      h = int(duration / 3600)
      m = int((duration % 3600) / 60)
      s = int(duration % 60)
      printf "%02d:%02d:%02d", h, m, s
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

render_video_grid() {
  local output="$1"
  local frame_dir="$2"
  local filename="$3"
  local byte_size="$4"
  local resolution="$5"
  local video_codec="$6"
  local audio_codec="$7"
  local duration_line="$8"
  local timestamp_line="$9"
  local swift_cache
  swift_cache="$(dirname "$output")/swift-module-cache"
  mkdir -p "$swift_cache"

  /usr/bin/swift -module-cache-path "$swift_cache" - \
    "$output" "$frame_dir" "$filename" "$byte_size" "$resolution" "$video_codec" "$audio_codec" "$duration_line" "$timestamp_line" \
    "$OUTPUT_WIDTH" "$OUTPUT_HEIGHT" "$HEADER_HEIGHT" "$PAGE_MARGIN" "$TILE_GAP" "$TILE_BORDER" "$COLUMNS" "$ROWS" "$TILE_WIDTH" "$TILE_HEIGHT" <<'SWIFT'
import AppKit

let args = CommandLine.arguments
guard args.count == 20,
      let width = Int(args[10]),
      let height = Int(args[11]),
      let headerHeight = Int(args[12]),
      let pageMargin = Int(args[13]),
      let tileGap = Int(args[14]),
      let tileBorder = Int(args[15]),
      let columns = Int(args[16]),
      let rows = Int(args[17]),
      let tileWidth = Int(args[18]),
      let tileHeight = Int(args[19]) else {
  exit(2)
}

let output = args[1]
let frameDir = args[2]
let filename = args[3]
let byteSize = args[4]
let resolution = args[5]
let videoCodec = args[6]
let audioCodec = args[7]
let duration = args[8]
let timestamps = args[9].split(separator: "|").map(String.init)
let size = NSSize(width: width, height: height)

let bytesPerRow = width * 4
let pixelData = UnsafeMutableRawPointer.allocate(byteCount: bytesPerRow * height, alignment: 16)
defer { pixelData.deallocate() }

guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let cgContext = CGContext(
        data: pixelData,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else {
  exit(3)
}
let context = NSGraphicsContext(cgContext: cgContext, flipped: false)

func drawOutlined(_ text: String, in rect: NSRect, font: NSFont, align: NSTextAlignment = .left) {
  let paragraph = NSMutableParagraphStyle()
  paragraph.lineBreakMode = .byTruncatingMiddle
  paragraph.alignment = align
  let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white,
    .strokeColor: NSColor.black,
    .strokeWidth: -3.0,
    .paragraphStyle: paragraph
  ]
  (text as NSString).draw(in: rect, withAttributes: attrs)
}

func drawBadge(in rect: NSRect) {
  NSColor(calibratedRed: 1.0, green: 0.83, blue: 0.04, alpha: 1.0).setFill()
  NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()

  let circle = NSRect(x: rect.midX - 26, y: rect.midY - 12, width: 52, height: 52)
  NSColor.white.setFill()
  NSBezierPath(ovalIn: circle).fill()

  let triangle = NSBezierPath()
  triangle.move(to: NSPoint(x: circle.midX - 8, y: circle.midY - 13))
  triangle.line(to: NSPoint(x: circle.midX - 8, y: circle.midY + 13))
  triangle.line(to: NSPoint(x: circle.midX + 14, y: circle.midY))
  triangle.close()
  NSColor(calibratedRed: 1.0, green: 0.83, blue: 0.04, alpha: 1.0).setFill()
  triangle.fill()

  let paragraph = NSMutableParagraphStyle()
  paragraph.alignment = .center
  let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.boldSystemFont(ofSize: 18),
    .foregroundColor: NSColor.black,
    .paragraphStyle: paragraph
  ]
  ("Player" as NSString).draw(in: NSRect(x: rect.minX, y: rect.minY + 10, width: rect.width, height: 24), withAttributes: attrs)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
NSColor(calibratedWhite: 0.94, alpha: 1.0).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

let infoLines = [
  "文件名:\(filename)",
  "大小:\(byteSize)",
  "分辨率:\(resolution)",
  "视频解码器:\(videoCodec) 音频解码器:\(audioCodec)",
  "时长:\(duration)"
]

let topY = CGFloat(height - 34)
for (i, line) in infoLines.enumerated() {
  drawOutlined(line, in: NSRect(x: 18, y: topY - CGFloat(i * 25), width: CGFloat(width - 220), height: 28), font: NSFont.boldSystemFont(ofSize: 22))
}
drawBadge(in: NSRect(x: CGFloat(width - 154), y: CGFloat(height - 128), width: 126, height: 110))

for row in 0..<rows {
  for column in 0..<columns {
    let index = row * columns + column
    let framePath = "\(frameDir)/frame_\(String(format: "%03d", index + 1)).jpg"
    guard let frame = NSImage(contentsOfFile: framePath) else {
      continue
    }

    let x = CGFloat(pageMargin + column * (tileWidth + tileGap))
    let y = CGFloat(height - headerHeight - (row + 1) * tileHeight - row * tileGap)
    let outer = NSRect(x: x, y: y, width: CGFloat(tileWidth), height: CGFloat(tileHeight))
    NSColor.black.setFill()
    NSBezierPath(rect: outer).fill()

    let inner = outer.insetBy(dx: CGFloat(tileBorder), dy: CGFloat(tileBorder))
    frame.draw(in: inner, from: .zero, operation: .copy, fraction: 1.0)

    if index < timestamps.count {
      drawOutlined(timestamps[index], in: NSRect(x: inner.minX, y: inner.minY + 8, width: inner.width, height: 26), font: NSFont.boldSystemFont(ofSize: 22), align: .center)
    }
  }
}
NSGraphicsContext.restoreGraphicsState()

guard let cgImage = cgContext.makeImage() else {
  exit(4)
}
let bitmap = NSBitmapImageRep(cgImage: cgImage)
guard let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
  exit(5)
}

try jpeg.write(to: URL(fileURLWithPath: output), options: .atomic)
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

  local width height fps size formatted_duration formatted_size video_codec audio_codec resolution timestamp_labels
  width="$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null | head -n 1 || true)"
  height="$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null | head -n 1 || true)"
  fps="$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null | awk -F/ 'NF == 2 && $2 != 0 { printf "%.2f", $1 / $2; next } { print }' | head -n 1 || true)"
  size="$(stat -f '%z' "$input" 2>/dev/null || echo 0)"
  formatted_duration="$(format_duration "$duration")"
  formatted_size="$(format_size "$size")"
  video_codec="$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null | head -n 1 || true)"
  audio_codec="$("$FFPROBE" -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null | head -n 1 || true)"
  resolution="${width:-?}x${height:-?}(${fps:-?}fps)"
  timestamp_labels="$(awk -v duration="$duration" -v start="$START_SECONDS" -v count="$FRAME_COUNT" '
    BEGIN {
      if (duration <= 0) exit 1
      actual_start = duration > start ? start : 0
      remaining = duration - actual_start
      for (i = 0; i < count; i++) {
        if (i == 0) {
          t = actual_start
        } else if (remaining <= 0) {
          t = actual_start
        } else {
          t = actual_start + remaining * i / count
        }
        if (t >= duration) t = duration > 0.2 ? duration - 0.2 : duration * 0.9
        if (t < 0) t = 0
        h = int(t / 3600)
        m = int((t % 3600) / 60)
        s = int(t % 60)
        sep = i == 0 ? "" : "|"
        printf "%s%02d:%02d:%02d", sep, h, m, s
      }
    }
  ')"

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

  render_video_grid "$output" "$tmpdir" "$base" "${formatted_size}(${size}bytes)" "$resolution" "${video_codec:-?}" "${audio_codec:-?}" "$formatted_duration" "$timestamp_labels" || {
    notify "视频网格生成失败" "合成视频网格失败：$base"
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
