#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT_DIR/assets/AppIcon.source.png"
ICONSET="$ROOT_DIR/assets/AppIcon.iconset"
ICNS="$ROOT_DIR/assets/AppIcon.icns"

if [[ ! -f "$SOURCE" ]]; then
  echo "Missing source image: $SOURCE" >&2
  exit 1
fi

mkdir -p "$ICONSET"
find "$ICONSET" -maxdepth 1 -type f -name '*.png' -delete

python3 - "$SOURCE" "$ICONSET" <<'PY'
from pathlib import Path
import sys
from PIL import Image

source = Path(sys.argv[1])
iconset = Path(sys.argv[2])
sizes = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

image = Image.open(source).convert("RGBA")
for filename, pixels in sizes:
    resized = image.resize((pixels, pixels), Image.Resampling.LANCZOS)
    resized.save(iconset / filename)
PY

rm -f "$ICNS"
sleep 1
if ! iconutil -c icns "$ICONSET" -o "$ICNS"; then
  sleep 1
  iconutil -c icns "$ICONSET" -o "$ICNS"
fi

echo "Generated $ICNS"
