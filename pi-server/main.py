from fastapi import FastAPI

app = FastAPI(title="Jukebox Pi Control Server", version="0.1.0")


@app.get("/api/status")
def status():
    return {
        "role": "pi_control_server",
        "playback": "remote_host",
        "message": "scaffold only — use iPhone/Mac host for full playback",
    }


@app.get("/api/state")
def state():
    return {
        "current": None,
        "elapsed": 0,
        "is_playing": False,
        "queue": [],
        "skip_vote": {"votes": 0, "required": 2, "voters": []},
        "connected_clients": 0,
        "playback_mode": "single_track",
        "playlist_lanes": [],
    }
