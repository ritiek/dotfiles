"""OpenAI-compatible /v1/audio/transcriptions backed by SenseVoice on the RKNN NPU."""

import logging
import os
import subprocess
import threading

import numpy as np
import sherpa_onnx
import uvicorn
from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import JSONResponse

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
log = logging.getLogger("sensevoice-stt")

recognizer = sherpa_onnx.OfflineRecognizer.from_sense_voice(
    model=os.environ["STT_MODEL"],
    tokens=os.environ["STT_TOKENS"],
    provider="rknn",
    language="en",
    use_itn=True,
)
# One RKNN context; FastAPI runs sync handlers in a threadpool.
lock = threading.Lock()
app = FastAPI()


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/v1/audio/transcriptions")
def transcribe(file: UploadFile = File(...), model: str = Form(default="sensevoice")):
    # Any container/codec in, 16 kHz mono float32 PCM out.
    proc = subprocess.run(
        ["ffmpeg", "-nostdin", "-loglevel", "error", "-i", "pipe:0",
         "-ar", "16000", "-ac", "1", "-f", "f32le", "pipe:1"],
        input=file.file.read(),
        capture_output=True,
    )
    if proc.returncode != 0:
        return JSONResponse({"error": proc.stderr.decode(errors="replace")}, status_code=400)

    with lock:
        stream = recognizer.create_stream()
        stream.accept_waveform(16000, np.frombuffer(proc.stdout, dtype=np.float32))
        recognizer.decode_stream(stream)
    text = stream.result.text.strip()
    log.info("%.1fs -> %r", len(proc.stdout) / 4 / 16000, text[:80])
    return {"text": text}


if __name__ == "__main__":
    uvicorn.run(app, host=os.environ.get("STT_HOST", "127.0.0.1"), port=int(os.environ.get("STT_PORT", "7258")))
