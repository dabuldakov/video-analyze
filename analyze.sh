#!/usr/bin/env bash
# Полный пайплайн: скачать видео с YouTube (через VPN-прокси), транскрибировать,
# вытащить кадры. Запускать на сервере трейдинга (VPN там). Локально VPN не включать.
#
#   ./analyze.sh "https://youtu.be/XXXX"
#
set -euo pipefail
URL="${1:?usage: ./analyze.sh <youtube-url>}"
PROXY="${PROXY:-http://172.19.0.1:1080}"

cd "$(dirname "$0")"
mkdir -p work
cd work

echo "== download =="
../venv/bin/yt-dlp --proxy "$PROXY" \
  -f "bv*[height<=1080]+ba/b[height<=1080]" --merge-output-format mp4 \
  -o "video.%(ext)s" "$URL"

echo "== audio =="
ffmpeg -y -i video.mp4 -vn -ac 1 -ar 16000 audio.wav 2>/dev/null
ffmpeg -y -i audio.wav -f s16le -ac 1 -ar 16000 audio.raw 2>/dev/null

echo "== transcript =="
../venv/bin/python ../transcribe.py

echo "== frames =="
mkdir -p frames
ffmpeg -y -i video.mp4 -vf "fps=1/10,scale=960:-1" -q:v 4 frames/f_%03d.jpg 2>/dev/null

echo "done: $(ls frames | wc -l) frames, transcript.txt"
