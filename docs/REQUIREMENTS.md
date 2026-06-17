# 要件定義 v4.0 実装状況

リポジトリ直下の `README.md`（要件定義書 v4.0 セクション）と、このリポジトリの現状を突合した引き継ぎ用メモ。

## 結論

**Apple Music を主再生サービスにする iPhone / iPad / Mac ホスト構成は実使用の入口まで到達。**
参加者 PWA、キュー、WebSocket、Apple Music カタログ検索・再生、プレイリスト追加、スキップ投票、セッション復旧、Mac ホストは実装済み。

一方で、要件定義のうち「各ユーザーの Apple Music 認証」「Spotify をホスト内で完全再生」「24時間耐久保証」「Raspberry Pi 分離」は未完了または外部制約あり。

## 実装済み

- 常設ホスト: `JukeboxHost`（iPhone / iPad）と `JukeboxHostMac`（macOS 14+）
- 参加者 PWA: Home / Search / Queue / Account
- REST API: `/api/state`, `/api/queue`, `/api/search`, `/api/playlists`, `/api/auth/status` など
- WebSocket: `/ws` で Now Playing / Queue を同期
- DB: SQLite に `queue`, `users`, `session`, `skip_votes`
- Apple Music: MusicKit 許可、カタログ曲検索、カタログプレイリスト検索、一括キュー追加、再生
- Spotify: OAuth、曲検索、プレイリスト検索、一括キュー追加、Spotify App deep link 再生
- YouTube: OAuth、API Key または OAuth トークンによる検索、プレイリスト取得、一括キュー追加、WKWebView 再生
- Phase 5: アニメーション、クロスフェード風表示、スキップ投票
- Phase 6: スリープ抑止、Wi-Fi 監視、サーバー再起動、セッション永続化

## 部分実装 / 制限

- Apple Music の「各ユーザー認証」は未対応。現実装は**ホスト端末の MusicKit 認証を全参加者で共有**する方式（Apple プラットフォーム制約）。
- Spotify 再生はホストアプリ内のネイティブ再生ではなく、Spotify アプリへの deep link。進捗は曲長ベースの推定。
- YouTube ログインは**参加者ごと**に PWA / JukeboxGuest の Account タブから行う。再生は WKWebView + IFrame API（進捗・終了・エラーをハンドル）。
- Spotify / YouTube OAuth の Redirect URI は LAN IP 不可のため、Netlify の HTTPS コールバックを使用。
- **24時間連続稼働**は復旧機構・セルフテスト API・耐久ログ UI まで実装済み。実機24hの結果記録のみ手動（`docs/durability-test.md`）。
- **ホスト自動発見**は PWA の「ホストを探す」（`Jukebox.local` + `/api/discover`）で対応。

## 未実装

- Raspberry Pi 制御サーバー分離の本番移行（Phase 7）。`pi-server/` v0.2 はキュー/state の互換サブセットのみ。
- 参加者ごとの Apple Music 個人ライブラリ同期

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
