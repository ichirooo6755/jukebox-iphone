# リモート参加（Issue #5）

同一 Wi-Fi にいなくても、インターネット経由でホストのキューに曲を送れる機能です。

## クイックスタート（開発）

### 1. リレーを起動

```bash
./scripts/run-relay.sh
```

### 2. ホストにリレー URL を設定

`JukeboxHost/Resources/Secrets.plist`:

```xml
<key>RELAY_BASE_URL</key>
<string>http://127.0.0.1:8780</string>
```

### 3. ホストアプリを起動

セットアップ画面の **「リモート参加」** に QR と参加コード（例: `K7M3NP`）が表示されます。

### 4. 参加者（別ネットワーク可）

スマホのブラウザでリモート参加 URL を開く:

```
http://<あなたのMacのIP>:8780/?room=K7M3NP
```

※ 開発時はリレーが Mac 上で動いているため、参加者もその Mac の IP:8780 へアクセスします。  
本番では `https://relay.example.com/?room=K7M3NP` のように **公開 HTTPS リレー** を使います。

## 本番構成

| コンポーネント | 役割 |
|----------------|------|
| ホスト Mac/iPhone | 音楽再生 + LAN サーバー + リレーへ外向き WS |
| リレーサーバー | 公開 URL、PWA 配信、API プロキシ |
| 参加者 | リレー URL + 参加コードのみ（Wi-Fi 不要） |

### リレーのデプロイ

```bash
docker build -f relay-server/Dockerfile -t jukebox-relay .
docker run -p 8780:8780 jukebox-relay
```

Fly.io / Railway 等にデプロイ後、`RELAY_BASE_URL` を HTTPS URL に設定してください。

## 参加者の接続方法

1. **QR スキャン** — ホスト画面のリモート参加 QR
2. **URL 直開き** — `https://<relay>/?room=<CODE>`
3. **Account タブ** — リレー URL + 参加コード →「リモート接続」

## OAuth（Spotify / YouTube）

リモート参加者の OAuth もリレー経由でホストへ転送されます。  
Redirect URI は従来どおり Netlify HTTPS を使用（変更不要）。

## 技術メモ

- ホスト登録: `POST /api/relay/rooms`（ルーム ID / シークレットは端末に永続化）
- ホスト接続: `WS /api/relay/host/ws`
- 参加者 API: `/api/relay/rooms/{code}/proxy/api/queue` 等
- リモート同期: HTTP 1秒ポーリング（WebSocket は LAN 向け）

## 関連ファイル

- `relay-server/main.py` — リレー本体
- `JukeboxHost/Services/RemoteRelayClient.swift` — ホスト側クライアント
- `web/js/api.js` — `configureRemoteJoin()`
- `docs/HOST_DISPLAY.md` — ホスト UI 説明
