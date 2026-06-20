#!/usr/bin/env python3
"""Moonshine STT server — OpenAI-compatible /v1/audio/transcriptions endpoint.

Loads the model once on startup and keeps it hot for subsequent calls.
Audio is converted to 16 kHz mono WAV via ffmpeg before transcription so any
format hermes sends (ogg/opus, mp3, wav, …) is accepted.

Environment variables:
  MOONSHINE_MODEL       TINY (default) or BASE
  MOONSHINE_STT_PORT    HTTP port (default: 7258)
  MOONSHINE_STT_HOST    Bind host (default: 127.0.0.1)
"""

import io
import logging
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import wave

import numpy as np
import uvicorn
from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import JSONResponse

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("moonshine-stt")

MODEL_NAME = os.environ.get("MOONSHINE_MODEL", "TINY").upper()
PORT       = int(os.environ.get("MOONSHINE_STT_PORT", "7258"))
HOST       = os.environ.get("MOONSHINE_STT_HOST", "127.0.0.1")

# Model locations inside the moonshine-voice download cache.
_MODEL_DIRS = {
    "TINY": ("tiny-en", "tiny-en"),
    "BASE": ("base-en", "base-en"),
}

app = FastAPI(title="moonshine-stt", version="1.0.0")
_transcriber = None


def _model_path(arch_name: str) -> pathlib.Path:
    outer, inner = _MODEL_DIRS[arch_name]
    base = (
        pathlib.Path.home()
        / ".cache"
        / "moonshine_voice"
        / "download.moonshine.ai"
        / "model"
    )
    return base / outer / "quantized" / inner


@app.on_event("startup")
async def _startup():
    global _transcriber
    from moonshine_voice import ModelArch, Transcriber, download

    arch  = getattr(ModelArch, MODEL_NAME)
    mpath = _model_path(MODEL_NAME)

    if not mpath.exists():
        log.info("Model not found at %s — downloading …", mpath)
        download("en")

    log.info("Loading %s model from %s …", MODEL_NAME, mpath)
    _transcriber = Transcriber(model_path=str(mpath), model_arch=arch)
    log.info("Model ready.")


def _to_wav_bytes(data: bytes) -> bytes:
    """Convert arbitrary audio bytes to 16 kHz mono WAV using ffmpeg."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        tmp_path = tmp.name

    try:
        proc = subprocess.run(
            [
                "ffmpeg", "-y",
                "-i", "pipe:0",
                "-ar", "16000",
                "-ac", "1",
                "-f", "wav",
                tmp_path,
            ],
            input=data,
            capture_output=True,
        )
        if proc.returncode != 0:
            raise RuntimeError(proc.stderr.decode(errors="replace"))
        with open(tmp_path, "rb") as f:
            return f.read()
    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass


def _load_wav(wav_bytes: bytes) -> tuple[np.ndarray, int]:
    with wave.open(io.BytesIO(wav_bytes), "rb") as f:
        sr     = f.getframerate()
        frames = f.readframes(f.getnframes())
    audio = np.frombuffer(frames, dtype=np.int16).astype(np.float32) / 32768.0
    return audio, sr


def _extract_text(transcript) -> str:
    """Strip moonshine timestamp prefixes like '[0.00s] ' from each line."""
    raw = str(transcript)
    lines = []
    for line in raw.splitlines():
        # Remove leading "[N.NNs] " timestamp prefix if present
        line = re.sub(r"^\[\d+\.\d+s\]\s*", "", line).strip()
        if line:
            lines.append(line)
    return " ".join(lines)


@app.get("/health")
async def health():
    return {"status": "ok", "model": MODEL_NAME, "ready": _transcriber is not None}


@app.post("/v1/audio/transcriptions")
async def transcribe(
    file:  UploadFile = File(...),
    model: str        = Form(default="moonshine-tiny"),
):
    if _transcriber is None:
        return JSONResponse({"error": "model not loaded"}, status_code=503)

    raw = await file.read()
    try:
        wav = _to_wav_bytes(raw)
        audio, sr = _load_wav(wav)
    except Exception as exc:
        log.error("Audio conversion failed: %s", exc)
        return JSONResponse({"error": f"audio conversion failed: {exc}"}, status_code=400)

    try:
        transcript = _transcriber.transcribe_without_streaming(audio, sr)
        text = _extract_text(transcript)
    except Exception as exc:
        log.error("Transcription failed: %s", exc)
        return JSONResponse({"error": f"transcription failed: {exc}"}, status_code=500)

    log.info("Transcribed %d samples → %r", len(audio), text[:80])
    return {"text": text}


if __name__ == "__main__":
    uvicorn.run(app, host=HOST, port=PORT, log_level="info")
