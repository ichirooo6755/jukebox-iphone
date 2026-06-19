# 要件定義 v4.0 実装状況

リポジトリ直下の `README.md`（要件定義書 v4.0 セクション）と、このリポジトリの現状を突合した引き継ぎ用メモ。

## 結論

**Apple Music を主再生サービスにする iPhone / iPad / Mac ホスト構成は実使用の入口まで到達。**
参加者 **PWA（Web）を標準 UI として維持**（Android・インストール不要・わかりやすさ）。JukeboxGuest は iOS 向けオプション。

一方で、要件定義のうち「Spotify をホスト内で完全再生」「24時間耐久保証」「Raspberry Pi 分離」は未完了または外部制約あり。Apple Music の参加者ライブラリは **JukeboxGuest** で対応（Web PWA 不可）。

## 実装済み

- 常設ホスト: `JukeboxHost`（iPhone / iPad）と `JukeboxHostMac`（macOS 14+）
- 参加者 PWA: Home / Search / Queue / Account
- 参加者ネイティブ: `JukeboxGuest`（Home / Search / Queue / Account、Live Activity 対応）
- REST API: `/api/state`, `/api/queue`, `/api/search`, `/api/playlists`, `/api/playlists/mine`, `/api/playlists/import-tracks`, `/api/auth/status` など
- WebSocket: `/ws` で Now Playing / Queue を同期
- DB: SQLite に `queue`, `users`, `session`, `skip_votes`
- Apple Music: MusicKit 許可、カタログ曲検索、カタログプレイリスト検索、一括キュー追加、再生
- Apple Music（参加者）: **JukeboxGuest** で端末ごとに MusicKit 許可 → マイライブラリプレイリスト取得 → ホストへ曲 ID 送信（`docs/APPLE_MUSIC_PARTICIPANT.md`）
- Spotify: OAuth（参加者ごと）、曲検索、プレイリスト検索、**自分のプレイリスト一覧**（`/api/playlists/mine`）、一括キュー追加、Spotify App deep link 再生
- YouTube: OAuth（参加者ごと）、API Key または OAuth トークンによる検索、**自分のプレイリスト一覧**、プレイリスト取得、一括キュー追加、WKWebView 再生
- Phase 5: アニメーション、クロスフェード風表示、スキップ投票
- Phase 6: スリープ抑止、Wi-Fi 監視、サーバー再起動、セッション永続化
- Host: QR 自動生成、HDMI 外部表示と音声出力の分離、画面消灯防止
- Guest: Web パリティ、Apple 風 UI、Dynamic Island / ロック画面 Live Activity

## 部分実装 / 制限

- Apple Music **再生**はホスト端末の MusicKit を全参加者で共有。**マイライブラリ取得**は JukeboxGuest のみ（PWA ブラウザでは MusicKit 個人ライブラリ API 不可）。
- Soundiiz / TuneMyMusic 等で他サービス → Apple Music に移行したプレイリストは、移行後に **JukeboxGuest** のマイライブラリからインポート可能。
- Spotify 再生はホストアプリ内のネイティブ再生ではなく、Spotify アプリへの deep link。進捗は曲長ベースの推定。
- YouTube ログインは**参加者ごと**に PWA / JukeboxGuest の Account タブから行う。再生は WKWebView + IFrame API（進捗・終了・エラーをハンドル）。
- Spotify / YouTube OAuth の Redirect URI は LAN IP 不可のため、Netlify の HTTPS コールバックを使用。
- **24時間連続稼働**は復旧機構・セルフテスト API・耐久ログ UI まで実装済み。実機24hの結果記録のみ手動（`docs/durability-test.md`）。
- **ホスト自動発見**は PWA の「ホストを探す」（`Jukebox.local` + `/api/discover`）で対応。
- **リモート参加**（同一 Wi-Fi 不要）は `relay-server` + `RELAY_BASE_URL`（`docs/REMOTE_JOIN.md`）。

## 未実装

- Raspberry Pi 制御サーバー分離の本番移行（Phase 7）。`pi-server/` v0.2 はキュー/state の互換サブセットのみ。

## 実使用前チェック

1. Xcode の Scheme を選択:
   - iPhone / iPad: `JukeboxHost`
   - Mac: `JukeboxHostMac`
2. `./scripts/import-auth-files.sh` で `.env` / `Secrets.plist` / Scheme 環境変数を同期
3. Redirect URI を登録（Spotify / Google Cloud 共通）:
   - `https://jukebox-join-ichirooo6755.netlify.app/oauth/callback.html`
   - `.env` の `OAUTH_PUBLIC_REDIRECT_URI` も同じ URL にする
4. ホスト端末で Apple Music を許可
5. ホストを開始し、表示された参加者 URL を同一LANのスマホで開く
6. Apple Music の曲検索 → キュー追加 → 再生を最初に確認

## 元ドキュメント

親 `README.md` の要件定義書 v4.0 セクションを参照。
