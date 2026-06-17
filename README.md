# マルチストリーミング・ジュークボックス

## このプロジェクトについて

**Jukebox** は、常設の iPhone / iPad / Mac を「ホスト」として置き、同じ Wi-Fi にいる参加者がスマホの Web アプリ（PWA）から曲やプレイリストをキューに入れ、みんなで聴く**民主的ジュークボックス**です。

### 何ができるか

- **ホスト**が Apple Music / Spotify / YouTube を再生し、スピーカーやイヤホンに出力
- **参加者**は QR コードまたは LAN URL で参加し、検索してキューに追加
- **スキップ投票**で過半数が同意すると次の曲へ
- **2つの再生モード**
  - **一曲ずつ** — 従来どおりキューに1曲ずつ追加
  - **プレイリスト選択** — 自分のプレイリストを登録し、複数人がいるときは 1/N ルーレットで次の曲を決定（git tree 風 UI で進捗表示）

### 誰が何をするか

| 役割 | 端末 | やること |
|------|------|----------|
| ホスト | 常設 iPhone/iPad/Mac | アプリ起動・再生・QR 表示 |
| 参加者 | **Android / iPhone / 任意のブラウザ** | **Web（PWA）が標準**。QR スキャンで参加・検索・キュー編集 |
| 参加者（iOS 任意） | iPhone / iPad | **JukeboxGuest** — Apple Music マイライブラリ・Live Activity など Web にない機能向け |

> **Web（PWA）は廃止しません。** Android ユーザーや「アプリを入れたくない」参加者の主力 UI です。Guest アプリは iOS 向けの**追加オプション**です。

### 技術の要点

- サーバーはホスト内蔵（ポート `8765`）、WebSocket でリアルタイム同期
- Spotify / YouTube の OAuth は LAN IP 不可のため **Netlify HTTPS** をコールバック専用に使用
- Apple Music はホストの MusicKit 許可で全員がカタログ検索を共有

タスクの進捗は `docs/todo.md`（**削除しない永続台帳**）、要件との突合は `docs/TRACEABILITY.md` を参照してください。ラズパイ構成は `docs/RASPBERRY_PI.md`、24h 耐久試験は `docs/durability-test.md` です。

---

民主的ジュークボックスの **Phase 1〜6** 実装です。常設 iPhone / iPad / Mac がホストとなり、参加者は同一 Wi-Fi 上の PWA からキューを編集します。

リポジトリ: [github.com/ichirooo6755/jukebox-iphone](https://github.com/ichirooo6755/jukebox-iphone)

実装状況の突合は `docs/TRACEABILITY.md`、引き継ぎ用の現状整理は `docs/REQUIREMENTS.md` を参照してください。

---

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
| ゲストネイティブアプリ（JukeboxGuest） | ✅ |
| 一曲ずつ / プレイリスト選択モード | ✅ |
| プレイリスト URL 直貼りインポート | ✅ |
| git tree 風ルーレット UI（途中参加マージ） | ✅ |
| OAuth プロフィール（名前・アイコン）永続化 | ✅ |
| Spotify / YouTube 参加者ごと OAuth | ✅ |
| ホスト音声出力選択（AirPlay/BT/有線/Mac） | ✅ |
| ラズパイ構成ガイド + pi-server スキャフォールド | ✅ |
| Phase 6 耐久ログ・試験手順書 | ✅ |
| PWA ホスト自動発見 | ✅ |
| 同期メトリクス（/api/metrics） | ✅ |

## セットアップ

```bash
cd jukebox-iphone
xcodegen generate
open JukeboxHost.xcodeproj
```

### iPhone / iPad

1. Scheme: **JukeboxHost** を選択
2. Xcode で Signing Team を設定
3. 実機にインストール（起動時にサーバーが自動開始）

### Mac

1. Scheme: **JukeboxHostMac** を選択
2. Run（⌘R）で起動
3. 参加者用 URL が画面左下・QR に表示される（コピー可）
4. 音声出力は **サウンド設定** から変更（再生画面のアイコンでも開けます）

### 参加者 — どちらを使う？

| 端末 | 推奨 | 理由 |
|------|------|------|
| **Android** | **Web（PWA）のみ** | ブラウザで QR → `http://<IP>:8765` |
| **iPhone（手軽に）** | **Web（PWA）** | インストール不要。ホーム画面に追加も可 |
| **iPhone（Apple Music マイライブラリ等）** | **JukeboxGuest**（任意） | 自分のプレイリスト・Dynamic Island |

**Web は今後もメインの参加者 UI として維持します。** ホストは引き続き `web/` を同梱して配信します。

### ゲストアプリ（JukeboxGuest）— iOS 向けオプション

1. Scheme: **JukeboxGuest** を選択
2. Account タブでホスト URL（例: `http://192.168.1.10:8765`）を入力して接続
3. Search タブでプレイリスト URL を貼り付けて追加
4. Spotify / YouTube は Account タブからログイン（参加者ごとに分離）

### 参加者（1回の QR スキャンで完結）— **Web が標準**

```
ホスト QR スキャン
  → ローカル PWA（http://<IP>:8765）
  → 名前入力 → 参加する
  → Spotify / YouTube は Account タブからログイン（1回だけ）
  → OAuth 完了後は Account タブに自動復帰
```

Netlify は**参加ランディングではなく** OAuth コールバック専用です。参加者が Netlify の URL を開く必要はありません。

### 参加者（手順）

1. ホスト画面の **QR ボタン** を押してコードを表示し、参加者のスマホでスキャン（または LAN URL を直接開く）
2. 同じ Wi-Fi 上で参加画面が開く（**2回目以降は自動でスキップ**）
3. 初回のみ名前を入力して **参加する**（リロード後もニックネームを記憶）→ Spotify / YouTube は Account タブから

### OAuth Redirect URI（Spotify / YouTube 共通）

LAN の `http://192.168.x.x` は Spotify / Google の Redirect URI として**登録できません**（Insecure / private IP エラー）。  
そのため **HTTPS の Netlify ページ**を OAuth コールバック専用に使います。

| 項目 | 内容 |
|------|------|
| Redirect URI | `https://jukebox-join-ichirooo6755.netlify.app/oauth/callback.html` |
| デプロイ | `./scripts/deploy-landing.sh` |
| 環境変数 | `OAUTH_PUBLIC_REDIRECT_URI`（上記 URL） |

**Spotify ダッシュボード**と **Google Cloud Console** の両方に、上記 Redirect URI を登録してください（`http://192.168.x.x` は削除して OK）。

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

2. 開発者コンソールに **Redirect URI** を登録:

| サービス | Redirect URI |
|----------|--------------|
| Spotify | `https://jukebox-join-ichirooo6755.netlify.app/oauth/callback.html` |
| YouTube (Google Cloud) | `https://jukebox-join-ichirooo6755.netlify.app/oauth/callback.html` |

> **YouTube ログイン（参加者端末）**: 各参加者が PWA の Account タブから自分の Google アカウントでログインします。Redirect URI には上記 **HTTPS URL** を登録してください（`http://192.168.x.x` は不可）。

3. 必要な環境変数（`configure-api-credentials.sh` が Xcode Scheme にも反映）:

| 変数名 | 用途 |
|--------|------|
| `SPOTIFY_CLIENT_ID` | Spotify OAuth |
| `SPOTIFY_CLIENT_SECRET` | Spotify OAuth |
| `YOUTUBE_API_KEY` | YouTube 公開検索 |
| `YOUTUBE_CLIENT_ID` | YouTube OAuth |
| `YOUTUBE_CLIENT_SECRET` | YouTube OAuth |
| `OAUTH_PUBLIC_REDIRECT_URI` | OAuth Redirect URI（HTTPS・Spotify / Google 共通） |

`.env` を手動編集した場合は `./scripts/sync-xcode-env.sh` で Scheme を再同期できます。

## プロジェクト構成

```
jukebox-iphone/
├── JukeboxHost/           # iOS / iPad / Mac ホストアプリ
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
├── web/                   # 参加者 PWA
│   └── landing/           # Netlify OAuth コールバック専用
├── scripts/               # セットアップ・デプロイ
└── docs/                  # 実装状況・突合表
```

## 音声出力について

外部 DAC は使いません。`AVAudioSession` を `.playback` に設定し、接続されている出力先を自動検出します。

- 3.5mm ジャック（iPhone 6s〜SE 2 など）
- Lightning / USB-C → 3.5mm 変換アダプタ
- 内蔵スピーカー / Mac スピーカー（有線未接続時）

## Apple Music の使い方

参加者は Web UI の Search タブで `Apple Music` を選び、曲・アーティスト・プレイリストを統合検索してキューに追加できます。再生はホスト端末の MusicKit が担当します（参加者は **曲 ID（music_id）をホストへ送信**する方式）。

検索対象は Apple Music カタログに加えて、ホスト端末で許可された Apple Music ライブラリの曲・プレイリストも含みます。参加者ごとの Apple ID ログインは Apple の制約により未対応です。

## 現状の制限

- Apple Music はホスト端末の MusicKit 認証を共有します。
- Spotify 再生はホストアプリ内の完全制御ではなく、Spotify アプリへの deep link です。
- YouTube ログインは**参加者ごと**に PWA の Account タブから行います（ニックネーム単位でトークン保存）。
- 24時間常設運用は復旧機構まで実装済みですが、実機耐久試験は未完了です。

## ライセンス

MIT

---

# 要件定義書 v4.0

## 1. システム概要

本システムは、複数ユーザー（3〜5人）がスマートフォンから同時アクセスし、1つの共通再生キューを編集・共有できる「民主的ジュークボックスシステム」である。

音楽サービスとして以下を混在利用可能とする。

- Apple Music（必須）
- Spotify
- YouTube

ユーザーはサービスを意識せず、同一のキューへ楽曲を追加できる。

システムはリアルタイム同期され、全参加者に現在再生状況およびキュー状態を即時反映する。

## 2. 設計方針

### 基本方針

開発初期段階では、**「iPhone only 構成」**を採用する。

理由:

- Apple Music との親和性が最も高い
- DRM 問題を回避しやすい
- システムが単純
- 開発速度が速い
- UX が自然

ただし、以下の問題が発生した場合:

- バックグラウンド制限
- WebSocket 切断
- PWA 制限
- パフォーマンス不足
- 複数同時接続不安定

については、**Raspberry Pi を制御サーバーとして追加する段階的拡張を可能にする設計**とする。

## 3. システムアーキテクチャ

### Phase 1（初期構成）

**iPhone only architecture**

```
参加者スマホ(3〜5人)
        ↓ Wi-Fi
常設iPhone
(API / Queue / Playback / UI)
        ↓
DAC
        ↓
スピーカー
```

### Phase 2（拡張構成）

安定性問題発生時: **Raspberry Pi hybrid architecture**

```
参加者スマホ
        ↓
Raspberry Pi
(API / Queue / WebSocket / DB)
        ↓
常設iPhone
(Playback + Display)
        ↓
DAC
        ↓
スピーカー
```

役割分離:

| デバイス | 役割 |
|----------|------|
| Raspberry Pi | Control Server |
| iPhone | Playback Device |

## 4. ハードウェア要件

### 4.1 初期構成（必須）

**常設 iPhone**

役割: システム本体。

推奨機種:

- iPhone SE
- iPhone 8
- iPhone XR

条件:

- Apple Music 動作可能
- Spotify 動作可能
- Wi-Fi 接続
- 常時給電
- スリープ無効化

**DAC**

外部 DAC 使用。

接続: Lightning / USB-C

要件:

- 常設運用可能
- 外部スピーカー出力可能
- 音量安定

**スピーカー**

任意。有線接続推奨。

### 4.2 拡張構成（任意）

**Raspberry Pi**

| 項目 | 内容 |
|------|------|
| 推奨 | Raspberry Pi 3 Model B |
| 最低 | Raspberry Pi Zero 2 W |
| 役割 | Queue 管理、API、WebSocket、DB |
| 制約 | 音声再生は行わない |

## 5. ネットワーク要件

全端末: 同一 LAN。

推奨: 5GHz Wi-Fi（リアルタイム同期安定化のため）。

## 6. ソフトウェア構成

### 6.1 常設 iPhone

**初期構成**

PWA（Progressive Web App）またはネイティブアプリ。

推奨: PWA で PoC 開始。問題発生時: ネイティブアプリ化。

**役割**

- Queue 管理
- API
- 再生制御
- 表示 UI
- WebSocket
- 状態同期

### 6.2 拡張構成

**Raspberry Pi** — Backend server（推奨: FastAPI）

機能:

- Queue DB
- REST API
- WebSocket
- 認証管理

**iPhone** — Playback + UI 専用。

## 7. UI 要件

### 7.1 User UI（参加者スマホ）

**Home**

Now Playing 表示:

- ジャケット画像
- 曲名
- アーティスト
- サービス種別
- 再生時間

**Search**

検索対象: Apple Music / Spotify / YouTube

入力: キーワード検索。

結果表示: ジャケット、曲名、アーティスト、サービス。

操作: ＋ Queue Add

**Queue**

表示: 曲順、曲名、アーティスト、サービス、追加者。

操作: ドラッグ並び替え、削除、Skip vote（任意）。

**Account**

ログイン状態表示。

### 7.2 Display UI（常設 iPhone）

**表示形式**: iPhone 縦画面。

| 領域 | 内容 |
|------|------|
| 上部 | 大きいジャケット表示 |
| 中央 | 曲名（大）、アーティスト名 |
| 中段 | 再生プログレスバー |
| 下段 | Next Queue（次 3〜5 曲: 曲名、サービス、追加者） |
| 状態表示 | Wi-Fi 状態、サービス接続状態 |

## 8. 認証要件

### Apple Music（最優先）

各ユーザー認証。用途: 楽曲検索、プレイリスト取得。必須。

> **実装メモ（2026-06）**: Apple の制約により、現行実装はホスト端末の MusicKit 認証を共有し、参加者は曲 ID を送信する方式。要件の「各ユーザー認証」は未達。

### Spotify

OAuth。用途: 検索、プレイリスト同期。

### YouTube

API Key / OAuth。

> **実装メモ（2026-06）**: YouTube は参加者ごとの OAuth に対応済み。

## 9. データベース設計

### queue

```sql
CREATE TABLE queue (
  id INTEGER PRIMARY KEY,
  position INTEGER,
  title TEXT,
  artist TEXT,
  artwork_url TEXT,
  service TEXT,
  music_id TEXT,
  duration INTEGER,
  added_by TEXT,
  added_at DATETIME
);
```

`service`: `apple_music` / `spotify` / `youtube`

### users

```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  nickname TEXT
);
```

## 10. 再生ロジック

### 曲追加

検索 → Queue Add → 全端末へ即時同期。

### 曲再生

キュー先頭判定 → 対象サービス切替 → 対象曲再生。

### サービス切替

Apple Music → Spotify → YouTube をシームレス切替。目標: 1秒以内。

### 再生終了

次曲自動遷移。

## 11. 非機能要件

| 項目 | 目標 |
|------|------|
| 同時接続 | 5人 |
| 更新反映 | 300ms 以内 |
| Queue 同期 | 1秒未満 |
| 連続稼働 | 24時間以上 |
| 自動復旧 | Wi-Fi 再接続、状態保持 |

## 12. 技術リスク管理

| ID | リスク |
|----|--------|
| R1 | Apple Music 自動再生制御（最重要） |
| R2 | Spotify / Apple Music 切替 |
| R3 | iOS PWA バックグラウンド制限 |

### リスク対応策

問題発生時: **Raspberry Pi 導入**（制御サーバー分離、構成変更可能）。

## 13. 開発ロードマップ

### Phase 0（PoC）

**最重要検証**

Goal: 以下が可能か確認。

- Apple Music 曲指定再生
- Spotify 曲指定再生
- YouTube 曲指定再生
- サービス切替
- 自動次曲

失敗時: 設計変更。期間: 1〜2週間。

### Phase 1

UI 基盤: Queue 表示、WS 同期、Now Playing。

### Phase 2

Apple Music 実装（最優先）。

### Phase 3

YouTube 実装。

### Phase 4

Spotify 実装。

### Phase 5

UX 改善: アニメーション、フェード、スキップ投票。

### Phase 6

耐久試験: 24時間稼働、Wi-Fi 切断復旧。

### Phase 7（必要時）

**Raspberry Pi 追加** — サーバー分離、スケール化。
