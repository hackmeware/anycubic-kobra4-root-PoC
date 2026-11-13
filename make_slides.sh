#!/usr/bin/env bash
# make_slides.sh - Video/GIF -> 480x320 XRGB8888 Raw-Frames fuer k4_display_demo.py
# Nutzung: ./make_slides.sh input.mp4|input.gif [max_frames]
set -euo pipefail
IN="${1:?Eingabevideo/GIF fehlt}"
MAX="${2:-120}"           # ~24s bei 0.2s/Frame
OUT=slides
mkdir -p "$OUT"; rm -f "$OUT"/*.raw

# Skalieren (Letterbox), 5 fps, pix_fmt rgb32 (XRGB8888), ein Rohstrom ...
ffmpeg -hide_banner -loglevel error -i "$IN" \
  -vf "scale=480:320:force_original_aspect_ratio=decrease,pad=480:320:(ow-iw)/2:(oh-ih)/2,fps=5" \
  -frames:v "$MAX" -pix_fmt rgb32 -f rawvideo "$OUT/all.raw"

# ... dann in 614400-Byte-Frames schneiden (480*320*4)
python3 - "$OUT" <<'PY'
import sys, pathlib
out = pathlib.Path(sys.argv[1]); data = (out/"all.raw").read_bytes()
FS = 480*320*4; n = 0
for i in range(0, len(data)-FS+1, FS):
    (out/f"slide{i:03d}.bin").write_bytes(data[i:i+FS]); n += 1
(out/"all.raw").unlink()
print(f"{n} Frames geschrieben")
PY

echo "Fertig: $(ls "$OUT"/*.raw 2>/dev/null | wc -l) Frames in $OUT/"
echo "Start:  python3 k4_display_demo.py <ip> --play $OUT"
