# マルチストリーミング・ジュークボックス (iPhone)

民主的ジュークボックスの **Phase 1: iPhone only** 実装です。常設 iPhone がホスト（API・キュー・再生・Display UI）となり、参加者は同一 Wi-Fi 上の PWA からキューを編集します。

## アーキテクチャ

```
参加者スマホ (PWA)  ──Wi-Fi──►  常設 iPhone (JukeboxHost)
                                    ├ REST API + WebSocket
                                    ├ SQLite キュー
                                    ├ Apple Music 再生 (MusicKit)
                                    ├ Spotify / YouTube 再生
                                    └ Display UI (縦画面)
```

Raspberry Pi によるサーバー分離は Phase 7 向けに `JukeboxCore` をパッケージ化しており、後から差し替え可能です。

## 機能

| 機能 | 状態 |
|------|------|
| キュー追加・削除・並び替え | ✅ |
| WebSocket リアルタイム同期 | ✅ |
| Now Playing / Display UI | ✅ |
| Apple Music 検索・再生 | ✅ |
| YouTube 検索・再生 | ✅ (APIキー要) |
| Spotify 検索 | ✅ (Client ID要) / 再生はアプリ起動 |
| 参加者 PWA (Home/Search/Queue/Account) | ✅ |

## セットアップ

### 1. ビルド

```bash
cd jukebox-iphone
xcodegen generate
open JukeboxHost.xcodeproj
```

Xcode で Signing Team を設定し、実機にインストールします。

### 2. Apple Music

- Apple Developer で MusicKit を有効化
- 実機で Apple Music の利用許可を許可

### 3. ホスト起動

1. 常設 iPhone で **JukeboxHost** を起動
2. 「ホストを開始」をタップ
3. 画面に表示される IP（例: `192.168.1.10:8765`）を確認

### 4. 参加者接続

参加者の iPhone Safari で `http://<ホストIP>:8765` を開く  
→ ホーム画面に追加すると PWA として利用可能

Account タブでニックネームとホスト URL を設定できます。

### 5. Spotify / YouTube（任意）

ホスト iPhone の環境変数、または Xcode Scheme の Environment Variables に設定:

| 変数 | 用途 |
|------|------|
| `SPOTIFY_CLIENT_ID` | Spotify 検索 |
| `SPOTIFY_CLIENT_SECRET` | Spotify 検索 |
| `YOUTUBE_API_KEY` | YouTube 検索 |

## プロジェクト構成

```
jukebox-iphone/
├── JukeboxHost/          # iOS ホストアプリ (SwiftUI)
├── Packages/JukeboxCore/ # 共有ロジック (API, DB, WS)
├── web/                  # 参加者 PWA
└── project.yml           # XcodeGen
```

## API

| Method | Path | 説明 |
|--------|------|------|
| GET | `/api/state` | 再生状態 + キュー |
| GET | `/api/queue` | キュー一覧 |
| POST | `/api/queue` | 曲追加 |
| DELETE | `/api/queue/:id` | 削除 |
| PUT | `/api/queue/reorder` | 並び替え |
| GET | `/api/search?q=&service=` | 検索 |
| GET | `/ws` | WebSocket 同期 |

## 既知の制限 (iPhone only)

- iOS バックグラウンドでローカルサーバーが切断される場合あり（要件定義 R3）→ 将来 Raspberry Pi で制御サーバー分離
- Spotify 再生は Spotify アプリへのディープリンク（iOS 制約）
- YouTube は iframe プレイヤーによる再生

## ライセンス

MIT
