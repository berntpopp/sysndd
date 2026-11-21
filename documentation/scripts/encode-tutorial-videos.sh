#!/usr/bin/env bash
# Re-encode the SysNDD tutorial videos for the documentation site.
# Usage: documentation/scripts/encode-tutorial-videos.sh [DIST_DIR]
#   DIST_DIR: the sysndd-educational dist/ folder (default ../sysndd-educational/dist
#   next to this repository). Writes documentation/static/videos/<id>.{mp4,vtt,webp}.
# Each video is tried at 1920x1080 CRF 28; if it exceeds MAX_BYTES it is re-encoded
# at 1280x720 (CRF 28, then 30). Audio is copied: the source AAC is already
# <= 128 kbit/s, and re-encoding would only add loss. Subtitles stay burned in.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dist="${1:-$here/../../../sysndd-educational/dist}"
out="$here/../static/videos"
max_bytes="${MAX_BYTES:-6291456}" # 6 MiB
ids=(a1-sysndd-overview a2-gene-panel a3-phenotype-search a4-api-mcp
  b1-grading-evidence b2-researching-gene b3-reading-paper b4-re-review
  b5-curating-new-gene c1-comparing-resources c2-phenotype-patterns c3-gene-networks)

mkdir -p "$out"
for id in "${ids[@]}"; do
  src="$dist/video-$id"
  [[ -f "$src/sysndd-$id.mp4" ]] || { echo "missing $src/sysndd-$id.mp4" >&2; exit 1; }
  for try in "1920:1080 28" "1280:720 28" "1280:720 30"; do
    read -r size crf <<<"$try"
    ffmpeg -v error -y -i "$src/sysndd-$id.mp4" -vf "scale=$size" \
      -c:v libx264 -profile:v high -preset slow -crf "$crf" -pix_fmt yuv420p \
      -c:a copy -movflags +faststart "$out/$id.mp4"
    bytes=$(stat -c %s "$out/$id.mp4")
    ((bytes <= max_bytes)) && break
  done
  ((bytes <= max_bytes)) || { echo "$id still $bytes bytes" >&2; exit 1; }
  ffmpeg -v error -y -i "$src/sysndd-$id.srt" "$out/$id.vtt"
  ffmpeg -v error -y -i "$src/thumbnail.png" -vf scale=1280:720 -c:v libwebp -quality 80 \
    "$out/$id.webp"
  echo "$id ${size/:/x} crf$crf $bytes bytes"
done
