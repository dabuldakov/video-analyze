#!/usr/bin/env bash
set -euo pipefail
# Кадры каждые 10 секунд (f_NNN.jpg = NNN*10 сек), ширина 960px.
mkdir -p frames
ffmpeg -y -i video.mp4 -vf "fps=1/10,scale=960:-1" -q:v 4 frames/f_%03d.jpg
echo "frames: $(ls frames | wc -l)"
