#!/usr/bin/env python3
"""
Lightpanda CDP proxy.
Uses asyncio TCP server to handle both plain HTTP and WebSocket on same port.
Handles nodriver's lowercase HTTP method (e.g. 'get /json/version HTTP/1.1').
Translates per-target WS paths to session-based routing via lightpanda's root WS.
"""
import asyncio, base64, hashlib, json, os, socket, subprocess, sys, urllib.request
import websockets
from websockets.connection import State

PROXY_HOST = "127.0.0.1"
PROXY_PORT = 9222
LP_BIN = os.environ.get("LIGHTPANDA_BIN") or sys.exit("LIGHTPANDA_BIN not set")

for arg in sys.argv[1:]:
    if arg.startswith("--remote-debugging-port="):
        PROXY_PORT = int(arg.split("=", 1)[1])
    elif arg.startswith("--remote-debugging-host="):
        PROXY_HOST = arg.split("=", 1)[1]

def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]

LP_PORT = free_port()

# --- CDP state shared across connections ---
_lp_ws = None
_lp_lock = asyncio.Lock()  # protect concurrent get_lp() calls
_lp_reader_task = None
_session_queues: dict = {}  # sessionId -> [Queue]
_root_queues: list = []     # Queue list for browser-level messages
_pending: dict = {}         # proxy cmd id -> Queue
_session_pending: dict = {} # client cmd id -> sessionId (for responses that come back without sessionId)
_sessions: dict = {}        # target_id -> sessionId
_id = 900000

def next_id():
    global _id
    _id += 1
    return _id

async def _lp_reader(ws):
    try:
        async for raw in ws:
            msg = json.loads(raw)
            sid = msg.get("sessionId")
            mid = msg.get("id")
            if sid and sid in _session_queues:
                for q in _session_queues[sid]:
                    q.put_nowait(msg)
            elif mid is not None and mid in _pending:
                _pending[mid].put_nowait(msg)
            elif mid is not None and mid in _session_pending:
                # lightpanda sends some session command results on root WS without sessionId
                target_sid = _session_pending.pop(mid)
                msg["sessionId"] = target_sid
                for q in _session_queues.get(target_sid, []):
                    q.put_nowait(msg)
            else:
                for q in _root_queues:
                    q.put_nowait(msg)
    except Exception:
        pass

async def get_lp():
    global _lp_ws, _lp_reader_task
    async with _lp_lock:
        if _lp_ws is None or _lp_ws.state != State.OPEN:
            _lp_ws = await websockets.connect(f"ws://127.0.0.1:{LP_PORT}/")
            _lp_reader_task = asyncio.create_task(_lp_reader(_lp_ws))
    return _lp_ws

async def lp_cmd(method, params):
    lp = await get_lp()
    mid = next_id()
    q = asyncio.Queue()
    _pending[mid] = q
    try:
        await lp.send(json.dumps({"id": mid, "method": method, "params": params}))
        return await asyncio.wait_for(q.get(), timeout=5.0)
    finally:
        _pending.pop(mid, None)

async def get_session(target_id):
    if target_id not in _sessions:
        r = await lp_cmd("Target.attachToTarget", {"targetId": target_id, "flatten": True})
        _sessions[target_id] = r["result"]["sessionId"]
    return _sessions[target_id]

# --- WebSocket frame codec (RFC 6455) ---
WS_GUID = b"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

def ws_accept_key(key: str) -> str:
    return base64.b64encode(hashlib.sha1(key.encode() + WS_GUID).digest()).decode()

def ws_handshake(key: str) -> bytes:
    return (
        b"HTTP/1.1 101 Switching Protocols\r\n"
        b"Upgrade: websocket\r\n"
        b"Connection: Upgrade\r\n"
        b"Sec-WebSocket-Accept: " + ws_accept_key(key).encode() + b"\r\n"
        b"\r\n"
    )

async def ws_recv(reader) -> tuple | None:
    """Read one WS frame. Returns (opcode, payload) or None on EOF/error."""
    try:
        hdr = await reader.readexactly(2)
        fin  = bool(hdr[0] & 0x80)
        opcode = hdr[0] & 0x0f
        masked = bool(hdr[1] & 0x80)
        plen = hdr[1] & 0x7f
        if plen == 126:
            plen = int.from_bytes(await reader.readexactly(2), "big")
        elif plen == 127:
            plen = int.from_bytes(await reader.readexactly(8), "big")
        mask = await reader.readexactly(4) if masked else b""
        payload = bytearray(await reader.readexactly(plen))
        if masked:
            for i in range(plen):
                payload[i] ^= mask[i % 4]
        return opcode, bytes(payload)
    except Exception:
        return None

def ws_frame(payload: bytes, opcode: int = 1) -> bytes:
    """Build unmasked server WS frame."""
    plen = len(payload)
    if plen < 126:
        return bytes([0x80 | opcode, plen]) + payload
    if plen < 65536:
        return bytes([0x80 | opcode, 126]) + plen.to_bytes(2, "big") + payload
    return bytes([0x80 | opcode, 127]) + plen.to_bytes(8, "big") + payload

def ws_close_frame() -> bytes:
    return bytes([0x88, 0x00])

# --- WebSocket proxy handlers ---

async def handle_ws_root(reader, writer):
    lp = await get_lp()
    q: asyncio.Queue = asyncio.Queue()
    _root_queues.append(q)

    async def c2l():
        while True:
            frame = await ws_recv(reader)
            if frame is None:
                break
            opcode, payload = frame
            if opcode == 8:   # close
                break
            if opcode == 9:   # ping -> pong
                writer.write(ws_frame(payload, opcode=10))
                await writer.drain()
                continue
            if opcode in (1, 2):
                await lp.send(payload.decode() if opcode == 1 else payload)

    async def l2c():
        while True:
            msg = await q.get()
            data = json.dumps(msg).encode()
            writer.write(ws_frame(data))
            await writer.drain()

    c2l_t = asyncio.create_task(c2l())
    l2c_t = asyncio.create_task(l2c())
    try:
        await asyncio.wait([c2l_t, l2c_t], return_when=asyncio.FIRST_COMPLETED)
    except Exception:
        pass
    finally:
        c2l_t.cancel(); l2c_t.cancel()
        if q in _root_queues:
            _root_queues.remove(q)

async def handle_ws_target(reader, writer, target_id: str):
    sid = await get_session(target_id)
    lp = await get_lp()
    q: asyncio.Queue = asyncio.Queue()
    _session_queues.setdefault(sid, []).append(q)

    async def c2l():
        while True:
            frame = await ws_recv(reader)
            if frame is None:
                break
            opcode, payload = frame
            if opcode == 8:
                break
            if opcode == 9:
                writer.write(ws_frame(payload, opcode=10))
                await writer.drain()
                continue
            if opcode in (1, 2):
                msg = json.loads(payload)
                mid = msg.get("id")
                msg["sessionId"] = sid
                if mid is not None:
                    _session_pending[mid] = sid
                await lp.send(json.dumps(msg))

    async def l2c():
        while True:
            msg = await q.get()
            msg.pop("sessionId", None)
            writer.write(ws_frame(json.dumps(msg).encode()))
            await writer.drain()

    c2l_t = asyncio.create_task(c2l())
    l2c_t = asyncio.create_task(l2c())
    try:
        await asyncio.wait([c2l_t, l2c_t], return_when=asyncio.FIRST_COMPLETED)
    except Exception:
        pass
    finally:
        c2l_t.cancel(); l2c_t.cancel()
        lst = _session_queues.get(sid, [])
        if q in lst:
            lst.remove(q)

# --- HTTP response helpers ---

def http_ok(body: str) -> bytes:
    b = body.encode()
    return (
        f"HTTP/1.1 200 OK\r\n"
        f"Content-Type: application/json\r\n"
        f"Content-Length: {len(b)}\r\n"
        f"Connection: close\r\n\r\n"
    ).encode() + b

def http_err(code: int, msg: str) -> bytes:
    b = msg.encode()
    return (
        f"HTTP/1.1 {code} Error\r\n"
        f"Content-Type: text/plain\r\n"
        f"Content-Length: {len(b)}\r\n"
        f"Connection: close\r\n\r\n"
    ).encode() + b

# --- Main TCP connection handler ---

async def handle_connection(reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
    try:
        # Read until end of HTTP headers
        buf = b""
        while b"\r\n\r\n" not in buf:
            chunk = await asyncio.wait_for(reader.read(4096), timeout=10.0)
            if not chunk:
                writer.close()
                return
            buf += chunk
            if len(buf) > 65536:
                writer.close()
                return

        header_block = buf[: buf.index(b"\r\n\r\n")]
        lines = header_block.split(b"\r\n")

        # Parse request line (normalize method to uppercase)
        first = lines[0].decode("latin-1")
        parts = first.split(" ", 2)
        path = parts[1] if len(parts) >= 2 else "/"

        # Parse headers (lowercase keys)
        hdrs: dict = {}
        for line in lines[1:]:
            if b":" in line:
                k, _, v = line.partition(b":")
                hdrs[k.strip().lower().decode("latin-1")] = v.strip().decode("latin-1")

        is_ws_upgrade = hdrs.get("upgrade", "").lower() == "websocket"

        if is_ws_upgrade:
            ws_key = hdrs.get("sec-websocket-key", "")
            writer.write(ws_handshake(ws_key))
            await writer.drain()
            if path.startswith("/devtools/page/"):
                target_id = path[len("/devtools/page/"):]
                await handle_ws_target(reader, writer, target_id)
            else:
                await handle_ws_root(reader, writer)
        else:
            # Plain HTTP request (nodriver HTTPApi, curl, etc.)
            if path == "/json/version":
                try:
                    data = json.loads(
                        urllib.request.urlopen(
                            f"http://127.0.0.1:{LP_PORT}/json/version", timeout=2
                        ).read()
                    )
                    data["webSocketDebuggerUrl"] = f"ws://{PROXY_HOST}:{PROXY_PORT}/"
                    writer.write(http_ok(json.dumps(data)))
                except Exception as e:
                    writer.write(http_err(500, str(e)))
            elif path in ("/json", "/json/list"):
                try:
                    raw = urllib.request.urlopen(
                        f"http://127.0.0.1:{LP_PORT}{path}", timeout=2
                    ).read()
                    targets = json.loads(raw)
                    for t in targets:
                        if "id" in t:
                            t["webSocketDebuggerUrl"] = (
                                f"ws://{PROXY_HOST}:{PROXY_PORT}/devtools/page/{t['id']}"
                            )
                    writer.write(http_ok(json.dumps(targets)))
                except Exception as e:
                    writer.write(http_err(500, str(e)))
            else:
                writer.write(http_err(404, "not found"))
            await writer.drain()
            writer.close()
    except Exception:
        try:
            writer.close()
        except Exception:
            pass

# --- Entry point ---

async def main():
    lp_proc = await asyncio.create_subprocess_exec(
        LP_BIN, "serve", "--host", "127.0.0.1", "--port", str(LP_PORT),
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    # Wait for lightpanda to be ready
    for _ in range(60):
        try:
            urllib.request.urlopen(f"http://127.0.0.1:{LP_PORT}/json/version", timeout=0.5)
            break
        except Exception:
            await asyncio.sleep(0.1)
    else:
        print(f"lightpanda failed to start on port {LP_PORT}", file=sys.stderr)
        sys.exit(1)

    server = await asyncio.start_server(handle_connection, PROXY_HOST, PROXY_PORT)
    try:
        async with server:
            await server.serve_forever()
    finally:
        lp_proc.terminate()
        try:
            await asyncio.wait_for(lp_proc.wait(), timeout=2)
        except asyncio.TimeoutError:
            lp_proc.kill()

asyncio.run(main())
