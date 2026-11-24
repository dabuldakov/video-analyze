# video-analyze

Анализ YouTube-видео (трейдинг): скачивание через VPN-прокси сервера, распознавание речи (faster-whisper), вытаскивание кадров (ffmpeg) и понимание «речь ↔ график» через Gemini.

## Принцип

```
видео
 ├─ аудио  ──► faster-whisper ──► текст с таймкодами
 └─ кадры  ──► ffmpeg (каждые 10с) ──► jpg
              └────────► Gemini (vision) читает кадры + расшифровку ──► отчёт
```

DeepSeek (текст) для финальной сводки опционально. Для графиков нужна vision-модель (Gemini).

## Как запускать

Всё на сервере трейдинга (`/opt/video-analyze`, там поднят VPN/sing-box на `172.19.0.1:1080`). Локально VPN не включать.

```bash
# 1. венв + зависимости (разово)
python3 -m venv venv
./venv/bin/pip install -U pip yt-dlp faster-whisper
apt-get install -y ffmpeg

# 2. скачать (через прокси)
./venv/bin/yt-dlp --proxy http://172.19.0.1:1080 \
  -f "bv*[height<=1080]+ba/b[height<=1080]" --merge-output-format mp4 \
  -o "video.%(ext)s" "$URL"

# 3. аудио -> raw PCM (обход PyAV-бага на Python 3.14)
ffmpeg -y -i video.mp4 -vn -ac 1 -ar 16000 audio.wav
ffmpeg -y -i audio.wav -f s16le -ac 1 -ar 16000 audio.raw

# 4. транскрипция (faster-whisper small, русский)
./venv/bin/python transcribe.py

# 5. кадры каждые 10с
ffmpeg -y -i video.mp4 -vf "fps=1/10,scale=960:-1" -q:v 4 frames/f_%03d.jpg

# 6. кадры + transcript.txt отдать Gemini-субагенту (vision)
```

Кадр `f_NNN.jpg` = момент `NNN × 10` секунд.

## Хранение результатов

Результаты (расшифровка, правила, report, meta) хранятся **в Postgres** — таблица
`video_analyses` в trading-БД. Этот репозиторий содержит **только пайплайн**
(скрипты скачивания/транскрипции/кадров). В git видео-артефакты не кладём.

Чтобы не разбирать видео заново — обращаемся к БД:

```sql
select video_id, title, testable, rules, transcript from video_analyses;
```

Дедуп по `video_id` (PK). Если `video_id` уже в БД — анализ не повторяется.

## Примечание

- faster-whisper 1.2.x ломается с новым PyAV на Python 3.14 (`metadata_errors`). Обход: декодировать аудио в raw PCM через ffmpeg и отдавать numpy-массив (`np.fromfile(...).astype(np.float32)/32768`), минуя `decode_audio`.
- Модель для vision: `opencode-go/gemini-4-argon` (покрывается OpenCode Go). `opencode/gemini-3.8-flash` — платный (нужны кредиты).
