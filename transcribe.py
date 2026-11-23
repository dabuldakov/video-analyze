import numpy as np
from faster_whisper import WhisperModel

# Обход PyAV-бага: читаем raw PCM (ffmpeg -f s16le), минуя faster_whisper.decode_audio.
raw = np.fromfile("audio.raw", dtype=np.int16).astype(np.float32) / 32768.0
model = WhisperModel("small", device="cpu", compute_type="int8")
segments, info = model.transcribe(raw, language="ru", vad_filter=True)
with open("transcript.txt", "w", encoding="utf-8") as f:
    for s in segments:
        f.write(f"[{s.start:7.1f} - {s.end:7.1f}] {s.text.strip()}\n")
print("done", info.language, round(info.duration, 1))
