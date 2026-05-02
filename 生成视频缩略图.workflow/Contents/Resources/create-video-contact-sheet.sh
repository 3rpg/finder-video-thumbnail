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
  notify "视频缩略图生成失败" "$1"
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

FFMPEG="$(find_tool ffmpeg)" || die "找不到 ffmpeg。请先运行：brew install ffmpeg"
FFPROBE="$(find_tool ffprobe)" || die "找不到 ffprobe。请先运行：brew install ffmpeg"

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
    notify "视频缩略图生成失败" "无法读取视频时长：$(basename "$input")"
    return 1
  fi

  local dir base name output tmpdir
  dir="$(dirname "$input")"
  base="$(basename "$input")"
  name="${base%.*}"
  output="$dir/${name}_thumbnail_1080p.jpg"
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
    notify "视频缩略图生成失败" "无法计算抽帧时间点：$base"
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
        notify "视频缩略图生成失败" "抽帧失败：$base"
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
    -y "$output" || {
      notify "视频缩略图生成失败" "拼接图片失败：$base"
      return 1
    }

  notify "视频缩略图已生成" "$(basename "$output")"
  printf '%s\n' "$output"
}

status=0
for input in "$@"; do
  make_sheet "$input" || status=1
done

exit "$status"
