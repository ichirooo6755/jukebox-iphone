# 要件定義 v4.0 実装状況

親ディレクトリの `要件定義.md` と、このリポジトリの現状を突合した引き継ぎ用メモ。

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

- Apple Music の「各ユーザー認証」は未対応。現実装は**ホスト端末の MusicKit 認証を全参加者で共有**する方式。
- Apple Music はカタログ検索に加えて、ホスト端末のライブラリ曲・ライブラリプレイリスト検索に対応。
- Spotify 再生はホストアプリ内のネイティブ再生ではなく、Spotify アプリへの deep link。進捗は曲長ベースの推定。
- YouTube ログインは**参加者ごと**に PWA の Account タブから行う。トークンはニックネーム単位でホストに保存される。
- YouTube OAuth の Redirect URI は `http://<host-ip>:8765/api/auth/youtube/callback` を Google Cloud に登録する。
- YouTube 再生は WKWebView 埋め込み。iOS/macOS の画面階層へ配置済みだが、自動再生や長時間安定性は実機確認が必要。
- 300ms / 1秒未満の同期目標はコード上リアルタイム同期だが、実測は未実施。
- 24時間連続稼働は復旧機構まで実装済みだが、耐久試験は未完了。
- mDNS は `_jukebox._tcp` の Bonjour 広告まで実装。PWA 側の自動探索 UI は未実装で、参加者 URL はホスト画面に表示・コピーする運用。

## 未実装

- Raspberry Pi 制御サーバー分離（Phase 7）。`JukeboxCore` を流用する想定。**`pi-audio-ui`（Pi 用 BT/AirPlay 試作）は本リポジトリには含めない**（jukebox とは別プロトタイプ）。
- 参加者ごとの Apple Music 個人ライブラリ同期
- 実機 24時間耐久試験の結果記録

## 実使用前チェック

1. Xcode の Scheme を選択:
   - iPhone / iPad: `JukeboxHost`
   - Mac: `JukeboxHostMac`
2. `./scripts/import-auth-files.sh` で `.env` / `Secrets.plist` / Scheme 環境変数を同期
3. Redirect URI を登録:
   - Spotify: `http://<host-ip>:8765/api/auth/spotify/callback`
   - YouTube: `http://<host-ip>:8765/api/auth/youtube/callback`
4. ホスト端末で Apple Music を許可
5. ホストを開始し、表示された参加者 URL を同一LANのスマホで開く
6. Apple Music の曲検索 → キュー追加 → 再生を最初に確認

## 元ドキュメント

親ディレクトリの `要件定義.md` を参照。
