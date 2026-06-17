from fastapi import FastAPI
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel

app = FastAPI(title="Jukebox Pi Control Server", version="0.2.0")

_state = {
    "current": None,
    "elapsed": 0,
    "is_playing": False,
    "queue": [],
    "skip_vote": {"votes": 0, "required": 2, "voters": []},
    "connected_clients": 0,
    "playback_mode": "single_track",
    "playlist_lanes": [],
    "last_roulette_participant": None,
    "session_started_at": None,
}


class QueueItemInput(BaseModel):
    title: str
    artist: str
    service: str
    music_id: str
    added_by: str
    duration: int = 0
    artwork_url: str | None = None


@app.get("/api/health")
def health():
    return PlainTextResponse("ok")


@app.get("/api/status")
def status():
    return {
        "role": "pi_control_server",
        "playback": "remote_host",
        "message": "Pi control server — queue/state API compatible subset",
    }


@app.get("/api/discover")
def discover():
    return {
        "name": "Jukebox Pi",
        "bonjour_type": "_jukebox._tcp",
        "hostname": "jukebox-pi.local",
        "port": 8765,
        "url": "http://jukebox-pi.local:8765",
    }


@app.get("/api/state")
def state():
    return _state


@app.get("/api/queue")
def queue():
    return _state["queue"]


@app.post("/api/queue")
def add_queue(item: QueueItemInput):
    entry = {
        "id": len(_state["queue"]) + 1,
        "position": len(_state["queue"]),
        "title": item.title,
        "artist": item.artist,
        "service": item.service,
        "music_id": item.music_id,
        "added_by": item.added_by,
        "duration": item.duration,
        "artwork_url": item.artwork_url,
    }
    _state["queue"].append(entry)
    if _state["current"] is None:
        _state["current"] = entry
        _state["is_playing"] = True
    return entry


@app.get("/api/metrics")
def metrics():
    return {
        "uptime_seconds": 0,
        "connected_clients": _state["connected_clients"],
        "broadcast_count": 0,
        "last_broadcast_ms_ago": None,
        "server_started_at": None,
    }
