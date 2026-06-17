# Pi Control Server（スキャフォールド）

将来、Raspberry Pi 上でキュー・WebSocket・OAuth を担当するための最小サーバーです。  
現状の本番は **iPhone/Mac 内蔵 JukeboxServer** です。

## 要件

- Python 3.11+
- Raspberry Pi OS（Zero 2 W 以上推奨）

## セットアップ

```bash
cd pi-server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8765
```

## API

現時点ではヘルスチェックと状態スタブのみ。本番 API は `Packages/JukeboxCore` の JukeboxServer と互換に拡張予定。

## systemd 例

```ini
[Unit]
Description=Jukebox Pi Control Server
After=network.target

[Service]
WorkingDirectory=/home/pi/jukebox-iphone/pi-server
ExecStart=/home/pi/jukebox-iphone/pi-server/.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8765
Restart=always

[Install]
WantedBy=multi-user.target
```
