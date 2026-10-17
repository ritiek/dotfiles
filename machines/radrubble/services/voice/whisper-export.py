"""Export Whisper tiny (20s window) to RKNN for whisper-stt-server.py.

Writes whisper-tiny-encoder.rknn and whisper-tiny-decoder-ctx<N>.rknn into the
current directory. Copy them to /var/lib/whisper-stt on radrubble together with
mel_80_filters.txt and vocab_en.txt from
https://github.com/airockchip/rknn_model_zoo/tree/main/examples/whisper/model

  encoder: mel [1,80,2000] -> cross-attn K/V of every decoder layer [8,6,1000,64]
  decoder: one token per step with a self-attention KV cache of N fixed slots
    token [1,1] int64, pos one-hot [N,1], mask additive [N,1], cache [8,N,384], kv
    -> logits [1,51865], this step's self-attn K/V [8,384]

Runs on any aarch64/x86_64 Linux box, in a Python 3.11 venv with:
  torch==2.2.0 numpy==1.26.4 protobuf==3.20.3 onnx==1.16.1 onnxsim==0.6.5
  openai-whisper==20231117 (needs setuptools<70, --no-build-isolation)
  rknn-toolkit2==2.3.2 (wheel from airockchip/rknn-toolkit2, --no-deps; must
  match radrubble's librknnrt 2.3.2)

Usage: python whisper-export.py [N=128]
"""
import sys

import onnx
import torch
import torch.nn.functional as F
import whisper
from onnxsim import simplify
from rknn.api import RKNN

N = int(sys.argv[1]) if len(sys.argv) > 1 else 128
model = whisper.load_model("tiny").to("cpu").eval().requires_grad_(False)
e, d, H, S = model.encoder, model.decoder, 6, 64 ** -0.5


def heads(x):  # [T,384] -> [6,T,64]
    return x.reshape(x.shape[0], H, 64).transpose(0, 1)


class Enc(torch.nn.Module):
    def __init__(self):
        super().__init__()
        self.m = model

    def forward(self, mel):
        # whisper's AudioEncoder.forward, minus its 30s shape assert: 20s of
        # audio is 1000 frames, which take the first 1000 positional embeddings.
        x = F.gelu(e.conv2(F.gelu(e.conv1(mel)))).permute(0, 2, 1)
        x = x + e.positional_embedding[: x.shape[1]]
        for b in e.blocks:
            x = b(x)
        a = e.ln_post(x)[0]
        return torch.stack([heads(f(a)) for b in d.blocks for f in (b.cross_attn.key, b.cross_attn.value)])


class Dec(torch.nn.Module):
    def __init__(self):
        super().__init__()
        self.d = d

    def forward(self, token, pos, mask, cache, kv):
        x = d.token_embedding(token)[0] + pos.transpose(0, 1) @ d.positional_embedding[:N]
        new = []
        for i, b in enumerate(d.blocks):
            h = b.attn_ln(x)
            q, k, v = b.attn.query(h), b.attn.key(h), b.attn.value(h)
            new += [k, v]
            # Write this step's K/V into its slot; mask hides the slots after it.
            K, V = heads(cache[2 * i] + pos * k), heads(cache[2 * i + 1] + pos * v)
            w = torch.softmax((K @ heads(q).transpose(1, 2)) * S + mask, dim=1)
            x = x + b.attn.out((w.transpose(1, 2) @ V).transpose(0, 1).reshape(1, 384))
            q = heads(b.cross_attn.query(b.cross_attn_ln(x)))
            w = torch.softmax((kv[2 * i] @ q.transpose(1, 2)) * S, dim=1)
            x = x + b.cross_attn.out((w.transpose(1, 2) @ kv[2 * i + 1]).transpose(0, 1).reshape(1, 384))
            x = x + b.mlp(b.mlp_ln(x))
        return (d.ln(x) @ d.token_embedding.weight.T).float(), torch.cat(new)


def export(mod, args, ins, outs, name):
    torch.onnx.export(mod, args, f"{name}.onnx", input_names=ins, output_names=outs, opset_version=12)
    m, ok = simplify(onnx.load(f"{name}.onnx"))
    assert ok, name
    onnx.save(m, f"{name}.onnx")
    rknn = RKNN()
    rknn.config(target_platform="rk3566")  # fp16, no quantization
    assert rknn.load_onnx(model=f"{name}.onnx") == 0, name
    assert rknn.build(do_quantization=False) == 0, name
    assert rknn.export_rknn(f"{name}.rknn") == 0, name
    rknn.release()


mel = torch.randn(1, 80, 2000)
export(Enc(), (mel,), ["mel"], ["kv"], "whisper-tiny-encoder")
pos = torch.zeros(N, 1)
pos[0] = 1
export(Dec(), (torch.zeros((1, 1), dtype=torch.long), pos, torch.zeros(N, 1), torch.zeros(8, N, 384), Enc()(mel)),
       ["token", "pos", "mask", "cache", "kv"], ["logits", "new"], f"whisper-tiny-decoder-ctx{N}")
