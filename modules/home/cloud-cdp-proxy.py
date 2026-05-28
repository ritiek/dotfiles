#!/usr/bin/env python3
"""
Cloud CDP proxy: shared cloud WS connection, multiple local connections.

Started by kindly-web-search pool manager as:
  chromium --remote-debugging-port=PORT [other-args-ignored]

Architecture:
  - ONE shared WSS connection to cloud Chrome (opened at startup)
  - N local WS connections from nodriver (browser + per-tab)
  - All local connections share the same cloud session
  - Cloud responses are broadcast to all local queues (nodriver filters by id/sessionId)

Fixes applied (same issues as lightpanda):
  1. Intercept Target.attachToBrowserTarget — cloud closes WS on this; fake the response
  2. Strip the fake proxy-browser-session sessionId before forwarding to cloud
"""
import asyncio
import sys
import json
import ssl
import os
import struct
import hashlib
import base64
import argparse

CLOUD_CDP_WSS = os.environ.get("CLOUD_CDP_WSS", "")

# ---------- SSL ---------------------------------------------------------------

def _ssl_ctx() -> ssl.SSLContext:
    ctx = ssl.create_default_context()
    for p in ["/etc/ssl/certs/ca-bundle.crt", "/etc/ssl/certs/ca-certificates.crt"]:
        if os.path.exists(p):
            ctx.load_verify_locations(p)
            return ctx
    return ctx


# ---------- minimal raw WS frame helpers (no extra deps) ----------------------

def _ws_accept(key: str) -> str:
    magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    return base64.b64encode(hashlib.sha1((key + magic).encode()).digest()).decode()


async def _ws_recv(reader: asyncio.StreamReader):
    """Read one WS frame → (opcode, payload_bytes)."""
    hdr = await reader.readexactly(2)
    opcode = hdr[0] & 0x0F
    masked = (hdr[1] >> 7) & 1
    plen = hdr[1] & 0x7F
    if plen == 126:
        plen = struct.unpack(">H", await reader.readexactly(2))[0]
    elif plen == 127:
        plen = struct.unpack(">Q", await reader.readexactly(8))[0]
    mask_key = await reader.readexactly(4) if masked else b"\x00\x00\x00\x00"
    raw = bytearray(await reader.readexactly(plen))
    if masked:
        for i in range(len(raw)):
            raw[i] ^= mask_key[i % 4]
    return opcode, bytes(raw)


async def _ws_send(writer: asyncio.StreamWriter, payload, opcode: int = 1):
    """Write one unmasked WS frame."""
    if isinstance(payload, str):
        payload = payload.encode()
    plen = len(payload)
    hdr = bytes([0x80 | opcode])
    if plen < 126:
        hdr += bytes([plen])
    elif plen < 65536:
        hdr += bytes([126]) + struct.pack(">H", plen)
    else:
        hdr += bytes([127]) + struct.pack(">Q", plen)
    writer.write(hdr + payload)
    await writer.drain()


# ---------- global shared state -----------------------------------------------

_cloud_ws = None          # shared websockets.asyncio.client.ClientConnection
_local_queues: list[asyncio.Queue] = []  # one per active local WS connection


async def _cloud_reader():
    """Read cloud responses forever; broadcast each message to all local queues."""
    global _cloud_ws
    try:
        async for msg in _cloud_ws:
            data = msg if isinstance(msg, bytes) else msg.encode()
            for q in list(_local_queues):
                q.put_nowait(data)
    except Exception as e:
        print(f"[cloud-cdp-proxy] cloud reader ended: {e}", file=sys.stderr)


# ---------- HTTP handler -------------------------------------------------------

async def _handle_http(writer: asyncio.StreamWriter, path: str):
    port = _PORT
    if "/json/version" in path:
        body = json.dumps({
            "Browser": "CloudCDP/1.0",
            "Protocol-Version": "1.3",
            "webSocketDebuggerUrl": f"ws://127.0.0.1:{port}/",
        })
    elif "/json" in path:
        body = "[]"
    else:
        body = "{}"
    resp = (
        f"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n"
        f"Content-Length: {len(body)}\r\n\r\n{body}"
    )
    writer.write(resp.encode())
    await writer.drain()


# ---------- WS handler --------------------------------------------------------

async def _handle_ws(
    reader: asyncio.StreamReader,
    writer: asyncio.StreamWriter,
    req_lines: list[str],
):
    global _cloud_ws

    # Handshake
    ws_key = ""
    for l in req_lines:
        if l.lower().startswith("sec-websocket-key:"):
            ws_key = l.split(":", 1)[1].strip()
            break
    accept = _ws_accept(ws_key)
    writer.write(
        f"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n"
        f"Connection: Upgrade\r\nSec-WebSocket-Accept: {accept}\r\n\r\n".encode()
    )
    await writer.drain()

    # Register a queue for cloud→local routing
    q: asyncio.Queue = asyncio.Queue()
    _local_queues.append(q)

    async def c2cloud():
        """Read from nodriver, apply fixes, send to shared cloud WS."""
        try:
            while True:
                op, data = await _ws_recv(reader)
                if op == 8:
                    break
                if op != 1:
                    await _cloud_ws.send(data)
                    continue

                try:
                    msg = json.loads(data)
                except Exception:
                    await _cloud_ws.send(data.decode())
                    continue

                mid = msg.get("id")
                method = msg.get("method", "")

                # Fix 1: intercept Target.attachToBrowserTarget — cloud closes WS on it
                if method == "Target.attachToBrowserTarget":
                    # Send AttachedToTarget event first (nodriver expects it)
                    event = json.dumps({
                        "method": "Target.attachedToTarget",
                        "params": {
                            "sessionId": "proxy-browser-session",
                            "targetInfo": {
                                "targetId": "browser",
                                "type": "browser",
                                "title": "CloudCDP",
                                "url": "",
                                "attached": True,
                                "canAccessOpener": False,
                                "browserContextId": "",
                            },
                            "waitingForDebugger": False,
                        },
                    }).encode()
                    await _ws_send(writer, event, 1)
                    result = json.dumps({"id": mid, "result": {"sessionId": "proxy-browser-session"}}).encode()
                    await _ws_send(writer, result, 1)
                    continue

                # Fix 2: strip fake proxy-browser-session sessionId
                if msg.get("sessionId") == "proxy-browser-session":
                    msg.pop("sessionId", None)

                await _cloud_ws.send(json.dumps(msg))
        except Exception as e:
            print(f"[cloud-cdp-proxy] c2cloud ended: {e}", file=sys.stderr)

    async def l2c():
        """Drain the queue and send to local nodriver connection."""
        try:
            while True:
                data = await q.get()
                await _ws_send(writer, data, 1)
        except Exception as e:
            print(f"[cloud-cdp-proxy] l2c ended: {e}", file=sys.stderr)

    tasks = [asyncio.create_task(c2cloud()), asyncio.create_task(l2c())]
    try:
        done, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
        for t in pending:
            t.cancel()
            try:
                await t
            except asyncio.CancelledError:
                pass
    finally:
        _local_queues.remove(q)


# ---------- connection dispatcher ---------------------------------------------

async def _handle(reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
    try:
        lines: list[str] = []
        while True:
            line = (await reader.readline()).decode("latin-1")
            lines.append(line)
            if line in ("\r\n", "\n", ""):
                break
        first = lines[0] if lines else ""
        path = first.split(" ")[1] if " " in first else "/"
        is_ws = any("upgrade: websocket" in l.lower() for l in lines)
        if is_ws:
            await _handle_ws(reader, writer, lines)
        else:
            await _handle_http(writer, path)
    except Exception as e:
        print(f"[cloud-cdp-proxy] handler error: {e}", file=sys.stderr)
    finally:
        try:
            writer.close()
        except Exception:
            pass


# ---------- main --------------------------------------------------------------

parser = argparse.ArgumentParser(add_help=False)
parser.add_argument("--remote-debugging-port", type=int, default=9222)
args, _ = parser.parse_known_args()
_PORT = args.remote_debugging_port


async def _main():
    global _cloud_ws

    import websockets.asyncio.client as wsc

    ctx = _ssl_ctx()
    print(f"[cloud-cdp-proxy] connecting to cloud...", file=sys.stderr)
    _cloud_ws = await wsc.connect(CLOUD_CDP_WSS, ssl=ctx, open_timeout=30)
    print(f"[cloud-cdp-proxy] cloud connected, starting proxy on port {_PORT}", file=sys.stderr)

    asyncio.create_task(_cloud_reader())

    server = await asyncio.start_server(_handle, "127.0.0.1", _PORT)
    async with server:
        await server.serve_forever()


asyncio.run(_main())
