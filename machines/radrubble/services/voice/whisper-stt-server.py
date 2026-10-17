"""OpenAI-compatible /v1/audio/transcriptions backed by Whisper on the RKNN NPU.

Whisper tiny with a 20s window, greedy decoding, no torch: mel spectrogram in
numpy, inference through librknnrt's C API. The encoder emits cross-attention
K/V for every decoder layer once per chunk; the decoder takes one token per
step with a self-attention KV cache. Models come from whisper-export.py and
live in STT_MODEL_DIR.
"""

import ctypes as C
import logging
import os
import subprocess
import threading
import time

import numpy as np
import uvicorn
from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import JSONResponse

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
log = logging.getLogger("whisper-stt")

SAMPLE_RATE, N_FFT, HOP, CHUNK_S = 16000, 400, 160, 20
N_FRAMES = CHUNK_S * SAMPLE_RATE // HOP  # 2000 mel frames per 20s window
EOT, SOT, LANG_EN, TRANSCRIBE, NO_TS = 50257, 50258, 50259, 50359, 50363
PREFIX = [SOT, LANG_EN, TRANSCRIBE, NO_TS]
N_CTX = 128  # decoder KV cache slots, fixed at export; caps tokens per chunk
IDX = np.arange(N_CTX)[:, None]

_lib = C.CDLL(os.environ["RKNN_LIB"])


class _InOutNum(C.Structure):
    _fields_ = [("n_input", C.c_uint32), ("n_output", C.c_uint32)]


class _TensorAttr(C.Structure):
    _fields_ = [
        ("index", C.c_uint32), ("n_dims", C.c_uint32), ("dims", C.c_uint32 * 16),
        ("name", C.c_char * 256), ("n_elems", C.c_uint32), ("size", C.c_uint32),
        ("fmt", C.c_int), ("type", C.c_int), ("qnt_type", C.c_int), ("fl", C.c_int8),
        ("zp", C.c_int32), ("scale", C.c_float), ("w_stride", C.c_uint32),
        ("size_with_stride", C.c_uint32), ("pass_through", C.c_uint8), ("h_stride", C.c_uint32),
    ]


class _Input(C.Structure):
    _fields_ = [("index", C.c_uint32), ("buf", C.c_void_p), ("size", C.c_uint32),
                ("pass_through", C.c_uint8), ("type", C.c_int), ("fmt", C.c_int)]


class _Output(C.Structure):
    _fields_ = [("want_float", C.c_uint8), ("is_prealloc", C.c_uint8), ("index", C.c_uint32),
                ("buf", C.c_void_p), ("size", C.c_uint32)]


# rknn_tensor_type values. fmt: 1 = NHWC (4D inputs only take NHWC), 3 = UNDEFINED.
_TYPES = {np.dtype(np.float32): 0, np.dtype(np.float16): 1, np.dtype(np.int64): 8}


class Model:
    def __init__(self, path):
        with open(path, "rb") as f:
            data = f.read()
        self.ctx = C.c_uint64(0)
        if _lib.rknn_init(C.byref(self.ctx), C.c_char_p(data), len(data), 0, None) != 0:
            raise RuntimeError(f"rknn_init failed for {path}")
        num = _InOutNum()
        _lib.rknn_query(self.ctx, 0, C.byref(num), C.sizeof(num))
        self.outputs = []
        for i in range(num.n_output):
            attr = _TensorAttr(index=i)
            _lib.rknn_query(self.ctx, 2, C.byref(attr), C.sizeof(attr))  # RKNN_QUERY_OUTPUT_ATTR
            self.outputs.append(tuple(attr.dims[: attr.n_dims]))

    def run(self, *inputs):
        # None keeps the input set by an earlier call (skips the per-run copy).
        inputs = [(i, np.ascontiguousarray(x)) for i, x in enumerate(inputs) if x is not None]
        ins = (_Input * len(inputs))()
        for j, (i, x) in enumerate(inputs):
            ins[j] = _Input(i, x.ctypes.data, x.nbytes, 0, _TYPES[x.dtype], 1 if x.ndim == 4 else 3)
        if _lib.rknn_inputs_set(self.ctx, len(inputs), ins) != 0 or _lib.rknn_run(self.ctx, None) != 0:
            raise RuntimeError("rknn run failed")
        res = [np.empty(s, dtype=np.float32) for s in self.outputs]
        outs = (_Output * len(res))()
        for i, r in enumerate(res):
            outs[i] = _Output(1, 1, i, r.ctypes.data, r.nbytes)
        ret = _lib.rknn_outputs_get(self.ctx, len(res), outs, None)
        _lib.rknn_outputs_release(self.ctx, len(res), outs)
        if ret != 0:
            raise RuntimeError("rknn_outputs_get failed")
        return res


model_dir = os.environ["STT_MODEL_DIR"]
filters = np.loadtxt(f"{model_dir}/mel_80_filters.txt", dtype=np.float32).reshape(80, 201)
vocab = {}
with open(f"{model_dir}/vocab_en.txt") as f:
    for line in f:
        k, _, v = line.rstrip("\n").partition(" ")
        vocab[int(k)] = v
encoder = Model(f"{model_dir}/whisper-tiny-encoder.rknn")
decoder = Model(f"{model_dir}/whisper-tiny-decoder-ctx{N_CTX}.rknn")
window = (0.5 - 0.5 * np.cos(2 * np.pi * np.arange(N_FFT) / N_FFT)).astype(np.float32)


def log_mel(audio):
    # Same as torch.stft(center=True, reflect pad, periodic hann) + whisper's log-mel.
    x = np.pad(audio, N_FFT // 2, mode="reflect")
    n = 1 + (len(x) - N_FFT) // HOP
    frames = x[np.arange(N_FFT)[None, :] + HOP * np.arange(n)[:, None]] * window
    mag = (np.abs(np.fft.rfft(frames, axis=1)) ** 2).T[:, :-1]
    spec = np.log10(np.maximum(filters @ mag, 1e-10))
    spec = (np.maximum(spec, spec.max() - 8.0) + 4.0) / 4.0
    mel = np.zeros((80, N_FRAMES), dtype=np.float32)
    mel[:, : min(spec.shape[1], N_FRAMES)] = spec[:, :N_FRAMES]
    return mel[None]


def split(audio):
    # Cut each 20s window at its quietest 0.1s within the last 8s, so words aren't
    # split and the decoder sees a natural end (a cut word makes it loop).
    step, frame, look = CHUNK_S * SAMPLE_RATE, SAMPLE_RATE // 10, 8 * SAMPLE_RATE
    chunks = []
    while len(audio) > step:
        energy = (audio[step - look : step].reshape(-1, frame) ** 2).sum(1)
        cut = step - look + int(energy.argmin()) * frame + frame // 2
        chunks.append(audio[:cut])
        audio = audio[cut:]
    return chunks + [audio]


def _repeats(out):
    # Length n of a token n-gram repeated 3 times at the end (greedy decoding loop).
    for n in range(1, 11):
        if len(out) >= 3 * n and out[-n:] == out[-2 * n : -n] == out[-3 * n : -2 * n]:
            return n
    return 0


def transcribe_chunk(audio):
    # NHWC once per chunk: the 4D K/V input only accepts NHWC.
    kv = np.ascontiguousarray(encoder.run(log_mel(audio))[0].astype(np.float16).transpose(0, 2, 3, 1))
    cache = np.zeros((8, N_CTX, 384), dtype=np.float16)
    tokens = list(PREFIX)
    for p in range(N_CTX):
        # Feed the token at position p; pos selects its cache slot, mask hides later slots.
        logits, new = decoder.run(np.array([[tokens[p]]]), (IDX == p).astype(np.float16),
                                  np.where(IDX <= p, 0, -1e4).astype(np.float16), cache,
                                  kv if p == 0 else None)
        cache[:, p] = new
        if p + 1 < len(tokens):
            continue  # still feeding the prefix
        # Text tokens and EOT only: no timestamps or other special tokens.
        nxt = int(logits[0, : EOT + 1].argmax())
        if nxt == EOT:
            break
        tokens.append(nxt)
        if n := _repeats(tokens[len(PREFIX) :]):
            del tokens[-2 * n :]
            break
    text = "".join(vocab.get(t, "") for t in tokens[len(PREFIX) :])
    # GPT-2 byte-level BPE: decode the byte-mapped string back to UTF-8.
    return bytes(_BYTE_DECODER.get(c, 32) for c in text).decode("utf-8", errors="replace")


def _bytes_to_unicode():
    bs = list(range(0x21, 0x7F)) + list(range(0xA1, 0xAD)) + list(range(0xAE, 0x100))
    cs = bs[:]
    n = 0
    for b in range(256):
        if b not in bs:
            bs.append(b)
            cs.append(256 + n)
            n += 1
    return {chr(c): b for b, c in zip(bs, cs)}


_BYTE_DECODER = _bytes_to_unicode()

# One RKNN context per model; FastAPI runs sync handlers in a threadpool.
lock = threading.Lock()
app = FastAPI()


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/v1/audio/transcriptions")
def transcribe(file: UploadFile = File(...), model: str = Form(default="whisper-tiny")):
    # Any container/codec in, 16 kHz mono float32 PCM out.
    proc = subprocess.run(
        ["ffmpeg", "-nostdin", "-loglevel", "error", "-i", "pipe:0",
         "-ar", "16000", "-ac", "1", "-f", "f32le", "pipe:1"],
        input=file.file.read(),
        capture_output=True,
    )
    if proc.returncode != 0:
        return JSONResponse({"error": proc.stderr.decode(errors="replace")}, status_code=400)

    audio = np.frombuffer(proc.stdout, dtype=np.float32)
    if len(audio) < SAMPLE_RATE // 10:
        return {"text": ""}
    t = time.monotonic()
    with lock:
        text = " ".join(transcribe_chunk(c).strip() for c in split(audio))
    log.info("%.1fs audio in %.1fs -> %r", len(audio) / SAMPLE_RATE, time.monotonic() - t, text[:80])
    return {"text": text.strip()}


if __name__ == "__main__":
    uvicorn.run(app, host=os.environ.get("STT_HOST", "127.0.0.1"), port=int(os.environ.get("STT_PORT", "7258")))
