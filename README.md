# マルチストリーミング・ジュークボックス (iPhone / iPad)

民主的ジュークボックスの **Phase 1〜6** 実装です。常設 iPhone / iPad がホストとなり、参加者は同一 Wi-Fi 上の PWA からキューを編集します。

要件定義との突合結果は `docs/TRACEABILITY.md`、引き継ぎ用の現状整理は `docs/REQUIREMENTS.md` を参照してください。

## 対応デバイス

| 項目 | 内容 |
|------|------|
| iOS | **16.0+**（iPhone 8 / SE 2 / XR 以降、iPad 6 世代以降） |
| macOS | **14.0+**（Apple Silicon / Intel） |
| 端末 | iPhone / iPad / **Mac** |
| 音声出力 | iPhone: 3.5mm / 変換アダプタ、Mac: スピーカー / ヘッドホン |

## 常設画面（2種類）

右上メニューで切り替え可能です。

1. **再生＋キュー** — Apple Music 風の Now Playing UI（横画面レイアウト対応）
   - 大きなアルバムアート、プログレスバー、再生コントロール、音量、次の曲リスト
2. **ビジュアライザ** — スペクトラム風のビジュアライザ＋アルバムアート

## 機能一覧（Phase 6 まで）

| 機能 | 状態 |
|------|------|
| キュー追加・削除・並び替え | ✅ |
| WebSocket リアルタイム同期 | ✅ |
| Apple Music 検索・再生 | ✅ Web UI から選択→キュー追加→ホスト再生 |
| YouTube / Spotify 検索 | ✅ |
| スキップ投票（過半数で次曲） | ✅ |
| 曲切替クロスフェード | ✅ |
| セッション永続化（再起動復旧） | ✅ |
| Wi-Fi 切断・自動サーバー復旧 | ✅ |
| 24時間常時稼働（スリープ無効化） | ✅ |
| 参加者 PWA | ✅ |

## セットアップ

```bash
cd jukebox-iphone
xcodegen generate
open JukeboxHost.xcodeproj
```

### iPhone / iPad

1. Scheme: **JukeboxHost** を選択
2. Xcode で Signing Team を設定
3. 実機にインストール → 「ホストを開始」

### Mac

1. Scheme: **JukeboxHostMac** を選択
2. Run（⌘R）で起動 → 「ホストを開始」
3. 参加者用 URL が画面に表示される（コピー可）

### 参加者

1. ホスト画面左上の **QR ボタン** を押してコードを表示し、参加者のスマホでスキャン
2. Netlify ランディング（`https://jukebox-join-ichirooo6755.netlify.app`）を経由して、同じ Wi-Fi 上のホスト PWA へ自動遷移
3. 名前を入力（空白なら `guest-番号`）→ 各サービスにログイン or Skip → キューに曲を追加

> QR は `https://jukebox-join-ichirooo6755.netlify.app/?host=http://<ホストIP>:8765` 形式です。ホストアプリが自動生成します。

### Netlify ランディング（参加者用 QR）

| 項目 | 内容 |
|------|------|
| 本番 URL | https://jukebox-join-ichirooo6755.netlify.app |
| ソース | `web/landing/` |
| 再デプロイ | `./scripts/deploy-landing.sh` |

ホスト側では `Secrets.plist` または `.env` に `JUKEBOX_JOIN_URL=https://jukebox-join-ichirooo6755.netlify.app` を設定してください（QR が Netlify 経由になります）。未設定の場合は LAN URL を直接 QR に載せます。

詳細は `web/landing/README.md` を参照。

### Spotify / YouTube（OAuth・プレイリスト）

1. 対話式セットアップを実行（推奨）:

```bash
cd jukebox-iphone
./scripts/configure-api-credentials.sh
```

または、認証ファイルから自動取り込み:

```bash
cd jukebox-iphone
# 初回のみ: cp secrets.example/* secrets/ して値を記入
./scripts/import-auth-files.sh
```

`secrets/spotify_auth.json` と `secrets/google_auth.json` を読み込み、`.env` / `Secrets.plist` / Xcode Scheme に反映します。テンプレートは `secrets.example/` を参照。

> **セキュリティ**: `secrets/` / `.env` / `Secrets.plist` は `.gitignore` 済みです。**GitHub に絶対に push しないでください。**

2. 開発者コンソールに **Redirect URI** を登録（ホスト iPhone の Wi-Fi IP を使用）:

| サービス | Redirect URI |
|----------|--------------|
| Spotify | `http://<ホストIP>:8765/api/auth/spotify/callback` |
| YouTube (Google Cloud) | `http://<ホストIP>:8765/api/auth/youtube/callback` |

> **YouTube ログイン（参加者端末）**: 各参加者が PWA の Account タブから自分の Google アカウントでログインします。Redirect URI には**ホストの LAN IP**（例: `http://192.168.43.8:8765/api/auth/youtube/callback`）を登録してください。Google Cloud の「承認済みの JavaScript 生成元」にも `http://<ホストIP>:8765` を追加してください。
>
> LAN IP が Google に拒否される場合は、`.env` に `YOUTUBE_OAUTH_REDIRECT_URI` で別の HTTPS コールバック URL を指定できます。

例:

- YouTube: `http://192.168.43.8:8765/api/auth/youtube/callback`（ホスト IP に置き換え）
- Spotify: `http://192.168.43.8:8765/api/auth/spotify/callback`（ホスト IP に置き換え）

> **注意**: 常設 iPhone の IP と Mac の IP は異なる場合があります。ホスト端末の IP はアプリ起動後の「ホストを開始」画面で確認してください。

3. 必要な環境変数（`configure-api-credentials.sh` が Xcode Scheme にも反映）:

| 変数名 | 用途 |
|--------|------|
| `SPOTIFY_CLIENT_ID` | Spotify OAuth |
| `SPOTIFY_CLIENT_SECRET` | Spotify OAuth |
| `YOUTUBE_API_KEY` | YouTube 公開検索 |
| `YOUTUBE_CLIENT_ID` | YouTube OAuth |
| `YOUTUBE_CLIENT_SECRET` | YouTube OAuth |
| `YOUTUBE_OAUTH_REDIRECT_URI` | （任意）YouTube OAuth の Redirect URI 上書き |

`.env` を手動編集した場合は `./scripts/sync-xcode-env.sh` で Scheme を再同期できます。

## プロジェクト構成

```
jukebox-iphone/
├── JukeboxHost/           # iOS / iPad アプリ
│   ├── Views/
│   │   ├── NowPlayingQueueView.swift  # 再生＋キュー画面
│   │   ├── VisualizerView.swift       # ビジュアライザ
│   │   └── DisplayContainerView.swift # 画面切替
│   └── Services/
│       ├── AudioOutputManager.swift   # 3.5mm 出力検出
│       └── HostLifecycleManager.swift # Phase 6 耐久性
├── secrets/               # 認証情報（gitignore・ローカルのみ）
├── secrets.example/       # 認証ファイルのテンプレート
├── Packages/JukeboxCore/  # API / DB / WebSocket
└── web/                   # 参加者 PWA
```

## 音声出力について

外部 DAC は使いません。`AVAudioSession` を `.playback` に設定し、接続されている出力先を自動検出します。

- 3.5mm ジャック（iPhone 6s〜SE 2 など）
- Lightning / USB-C → 3.5mm 変換アダプタ
- 内蔵スピーカー（有線未接続時）

## Apple Music の使い方

参加者は Web UI の Search タブで `Apple Music` を選び、曲またはプレイリストを検索してキューに追加できます。再生はホスト端末（iPhone / iPad / Mac）の MusicKit が担当します。

検索対象は Apple Music カタログに加えて、ホスト端末で許可された Apple Music ライブラリの曲・プレイリストも含みます。参加者ごとの Apple ID / 個人ライブラリ同期は Apple の制約により未対応です。

## Phase 7（将来）

Raspberry Pi を制御サーバーとして追加し、`JukeboxCore` をそのまま流用可能な設計です。

## 現状の制限

- Apple Music はホスト端末の MusicKit 認証を共有します。ホスト端末のライブラリ検索は対応済みですが、参加者ごとの Apple ID ログインや個人ライブラリ同期は未対応です。
- Spotify 再生はホストアプリ内の完全制御ではなく、Spotify アプリへの deep link です。
- YouTube ログインは**参加者ごと**に PWA の Account タブから行います（ニックネーム単位でトークン保存）。
- 24時間常設運用は復旧機構まで実装済みですが、実機耐久試験は未完了です。

## ライセンス

MIT
