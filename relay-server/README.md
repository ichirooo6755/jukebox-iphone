# Jukebox Remote Relay

同一 Wi-Fi 不要で参加者が曲をホストへ送れるリレーサーバー（Issue #5）。

## 仕組み

```
参加者 (インターネット) ──HTTPS──► リレー (公開 URL)
                                      ▲
ホスト (自宅) ──WebSocket (外向き)────┘
```

- ホストは **インバウンドポート開放不要**（NAT 越えはアウトバウンド WS のみ）
- 参加者は `https://<relay>/?room=ABC123` を開く（PWA もリレーから配信）
- API は `/api/relay/rooms/{code}/proxy/*` 経由でホストの JukeboxServer へ転送

## ローカル起動

```bash
./scripts/run-relay.sh
```

- リレー: `http://127.0.0.1:8780`
- PWA: `http://127.0.0.1:8780/?room=<参加コード>`

## ホスト設定

`Secrets.plist` または `.env`:

```
RELAY_BASE_URL=http://127.0.0.1:8780
```

本番では Fly.io / Railway 等にデプロイした HTTPS URL を設定。

ホスト起動後、セットアップ画面に **リモート参加 QR** と参加コードが表示されます。

## 本番デプロイ例（Docker）

```bash
cd relay-server
docker build -t jukebox-relay .
docker run -p 8780:8780 jukebox-relay
```

## API

| エンドポイント | 説明 |
|----------------|------|
| `POST /api/relay/rooms` | ホストがルーム登録 |
| `WS /api/relay/host/ws?room_id=&secret=` | ホスト接続 |
| `GET /api/relay/rooms/{code}` | 参加者向け discover |
| `*/api/relay/rooms/{code}/proxy/*` | ホスト API プロキシ |

## 制限（v1）

- リモート参加者は HTTP ポーリング同期（WebSocket はローカルのみ）
- リレーはインメモリ（再起動でルーム消去。ホスト再起動で再登録）
- 本番運用では HTTPS + レート制限を推奨

詳細: `docs/REMOTE_JOIN.md`
