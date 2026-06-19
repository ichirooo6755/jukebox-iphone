"""
Jukebox Remote Relay — Issue #5

ホストがアウトバウンド WebSocket で接続し、ゲストはインターネット経由で
/api/relay/rooms/{code}/proxy/* へリクエストを送る。同一 Wi-Fi 不要。
"""

from __future__ import annotations

import asyncio
import json
import os
import secrets
import string
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException, Request, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse, PlainTextResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

JOIN_CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
JOIN_CODE_LEN = 6

app = FastAPI(title="Jukebox Remote Relay", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@dataclass
class Room:
    room_id: str
    host_secret: str
    join_code: str
    host_ws: WebSocket | None = None
    cached_state: dict[str, Any] | None = None


rooms_by_code: dict[str, Room] = {}
rooms_by_id: dict[str, Room] = {}
pending_requests: dict[str, asyncio.Future[dict[str, Any]]] = {}


class RoomRegisterRequest(BaseModel):
    room_id: str | None = None
    host_secret: str | None = None
    join_code: str | None = None


def _new_join_code() -> str:
    for _ in range(200):
        code = "".join(secrets.choice(JOIN_CODE_CHARS) for _ in range(JOIN_CODE_LEN))
        if code not in rooms_by_code:
            return code
    raise HTTPException(status_code=500, detail="参加コードを生成できません")


def _room_payload(room: Room, request: Request) -> dict[str, Any]:
    base = str(request.base_url).rstrip("/")
    proxy = f"{base}/api/relay/rooms/{room.join_code}/proxy"
    return {
        "room_id": room.room_id,
        "host_secret": room.host_secret,
        "join_code": room.join_code,
        "relay_url": base,
        "proxy_url": proxy,
        "join_url": f"{base}/?room={room.join_code}",
        "online": room.host_ws is not None,
    }


@app.get("/api/health")
def health() -> PlainTextResponse:
    return PlainTextResponse("ok")


@app.get("/api/relay/status")
def relay_status() -> dict[str, Any]:
    return {
        "role": "remote_relay",
        "rooms": len(rooms_by_code),
        "connected_hosts": sum(1 for room in rooms_by_code.values() if room.host_ws is not None),
    }


@app.post("/api/relay/rooms")
def register_room(body: RoomRegisterRequest, request: Request) -> dict[str, Any]:
    if body.room_id and body.room_id in rooms_by_id:
        room = rooms_by_id[body.room_id]
        if body.host_secret != room.host_secret:
            raise HTTPException(status_code=403, detail="host_secret が一致しません")
        return _room_payload(room, request)

    room_id = body.room_id or secrets.token_urlsafe(16)
    host_secret = body.host_secret or secrets.token_urlsafe(32)
    join_code = body.join_code or _new_join_code()
    if join_code in rooms_by_code:
        raise HTTPException(status_code=409, detail="参加コードが既に使われています")

    room = Room(room_id=room_id, host_secret=host_secret, join_code=join_code)
    rooms_by_code[join_code] = room
    rooms_by_id[room_id] = room
    return _room_payload(room, request)


@app.get("/api/relay/rooms/{join_code}")
def discover_room(join_code: str, request: Request) -> dict[str, Any]:
    room = rooms_by_code.get(join_code.upper())
    if not room:
        raise HTTPException(status_code=404, detail="ルームが見つかりません")
    base = str(request.base_url).rstrip("/")
    proxy = f"{base}/api/relay/rooms/{room.join_code}/proxy"
    return {
        "name": "Jukebox",
        "bonjour_type": "_jukebox._tcp",
        "hostname": "remote",
        "port": 443,
        "join_code": room.join_code,
        "online": room.host_ws is not None,
        "url": proxy,
        "play_url": f"{base}/?room={room.join_code}",
        "state": room.cached_state,
    }


@app.websocket("/api/relay/host/ws")
async def host_websocket(websocket: WebSocket, room_id: str, secret: str) -> None:
    room = rooms_by_id.get(room_id)
    if not room or secret != room.host_secret:
        await websocket.close(code=4003)
        return

    await websocket.accept()
    room.host_ws = websocket
    try:
        while True:
            message = await websocket.receive_json()
            msg_type = message.get("type")
            if msg_type == "response":
                req_id = message.get("id")
                future = pending_requests.pop(req_id, None)
                if future and not future.done():
                    future.set_result(message)
            elif msg_type == "state":
                room.cached_state = message.get("payload")
    except WebSocketDisconnect:
        pass
    finally:
        if room.host_ws is websocket:
            room.host_ws = None


async def _forward_to_host(room: Room, method: str, path: str, body: Any, headers: dict[str, str]) -> dict[str, Any]:
    if room.host_ws is None:
        if method == "GET" and path == "/api/state" and room.cached_state is not None:
            return {"status": 200, "body": room.cached_state, "headers": {}}
        raise HTTPException(status_code=503, detail="ホストがオフラインです。ホストアプリを起動してください。")

    req_id = secrets.token_urlsafe(12)
    loop = asyncio.get_running_loop()
    future: asyncio.Future[dict[str, Any]] = loop.create_future()
    pending_requests[req_id] = future
    await room.host_ws.send_json(
        {
            "type": "request",
            "id": req_id,
            "method": method,
            "path": path,
            "body": body,
            "headers": {k: v for k, v in headers.items() if k.lower() not in {"host", "content-length"}},
        }
    )
    try:
        return await asyncio.wait_for(future, timeout=35.0)
    except asyncio.TimeoutError:
        pending_requests.pop(req_id, None)
        raise HTTPException(status_code=504, detail="ホスト応答がタイムアウトしました")
    finally:
        pending_requests.pop(req_id, None)


def _response_from_host(message: dict[str, Any]) -> JSONResponse:
    status = int(message.get("status", 500))
    body = message.get("body")
    extra_headers = message.get("headers") or {}
    headers = {"Access-Control-Allow-Origin": "*"}
    for key, value in extra_headers.items():
        lowered = key.lower()
        if lowered in {"content-length", "transfer-encoding", "connection"}:
            continue
        headers[key] = value
    if body is None:
        return JSONResponse(status_code=status, headers=headers)
    return JSONResponse(content=body, status_code=status, headers=headers)


@app.api_route(
    "/api/relay/rooms/{join_code}/proxy/{path:path}",
    methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
)
async def proxy_to_host(join_code: str, path: str, request: Request) -> JSONResponse:
    if request.method == "OPTIONS":
        return JSONResponse(status_code=204, headers={"Access-Control-Allow-Origin": "*"})

    room = rooms_by_code.get(join_code.upper())
    if not room:
        raise HTTPException(status_code=404, detail="ルームが見つかりません")

    api_path = f"/{path}"
    if request.url.query:
        api_path = f"{api_path}?{request.url.query}"

    body: Any = None
    if request.method in {"POST", "PUT", "PATCH"}:
        raw = await request.body()
        if raw:
            try:
                body = json.loads(raw)
            except json.JSONDecodeError:
                body = raw.decode("utf-8", errors="replace")

    message = await _forward_to_host(room, request.method, api_path, body, dict(request.headers))
    return _response_from_host(message)


WEB_ROOT = Path(os.environ.get("WEB_ROOT", str(Path(__file__).resolve().parent.parent / "web")))
if WEB_ROOT.is_dir():
    app.mount("/", StaticFiles(directory=str(WEB_ROOT), html=True), name="web")
