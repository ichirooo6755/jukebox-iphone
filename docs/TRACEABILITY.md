# 要件トレーサビリティ

`README.md` の要件定義書 v4.0 セクションと実装の突合表。2026-06-17 時点。

## 判定

| 判定 | 意味 |
|------|------|
| 完了 | コード上の機能実装あり。ビルド対象に含まれる |
| 部分 | 機能はあるが制約・代替実装・実機確認待ちがある |
| 未完 | 未実装または将来フェーズ |

## システム構成

| 要件 | 判定 | 実装 / 補足 |
|------|------|-------------|
| 参加者 3〜5人が同一キューを共有 | 完了 | `JukeboxStore`, `JukeboxServer`, PWA |
| Apple Music / Spotify / YouTube 混在キュー | 完了 | `MusicService`, `QueueItem`, Web UI のサービス選択 |
| リアルタイム同期 | 完了 | `/ws`, `JukeboxWebSocketHandler` |
| iPhone only 初期構成 | 完了 | `JukeboxHost` |
| Mac ホスト | 完了 | `JukeboxHostMac` |
| Raspberry Pi hybrid | 未完 | Phase 7。`JukeboxCore` を流用できる構造のみ |

## 参加者 UI

| 要件 | 判定 | 実装 / 補足 |
|------|------|-------------|
| Home: Now Playing 表示 | 完了 | `web/index.html`, `web/js/app.js` |
| Search: Apple Music / Spotify / YouTube | 完了 | `/api/search`, `SearchCoordinator` |
| Search: プレイリスト | 完了 | `/api/playlists`, `/api/playlists/import` |
| Queue: 表示 / 削除 / 並び替え | 完了 | PWA drag & drop、REST API |
| Queue: Skip vote | 完了 | `/api/playback/vote-skip`, `skip_votes` |
| Account: ログイン状態表示 | 完了 | `/api/auth/status` |
| 自動ホスト発見 | 部分 | Bonjour サービス広告あり。PWA 側の自動探索 UI は未実装 |

## 常設表示 UI

| 要件 | 判定 | 実装 / 補足 |
|------|------|-------------|
| 大きいジャケット / 曲名 / アーティスト | 完了 | `NowPlayingQueueView` |
| プログレスバー | 完了 | `NowPlayingQueueView`, `PlaybackEngine` |
| Next Queue 3〜5曲 | 完了 | `NowPlayingQueueView` |
| Wi-Fi 状態 | 完了 | `HostSetupView`, `HostServerStatus` |
| サービス接続状態 | 完了 | PWA Account とホスト画面のステータスバッジに表示 |
| ビジュアライザ | 追加実装 | `VisualizerView` |

## 認証 / サービス連携

| 要件 | 判定 | 実装 / 補足 |
|------|------|-------------|
| Apple Music 楽曲検索 | 完了 | `AppleMusicSearchService.search` |
| Apple Music プレイリスト取得 | 完了 | カタログプレイリストとホスト端末のライブラリプレイリストを検索 |
| Apple Music 各ユーザー認証 | 部分 | ホスト端末の MusicKit 認証を共有。Web 参加者ごとの Apple ID 認証は Apple 制約により未対応 |
| Spotify OAuth | 完了 | `SpotifySearchService` |
| Spotify 検索 / プレイリスト同期 | 完了 | Spotify Web API |
| OAuth トークン永続化 | 完了 | Spotify / YouTube のユーザートークンをローカルに保持 |
| YouTube API Key | 完了 | API Key 利用可。未設定でも OAuth ログイン後は検索できるよう補完 |
| YouTube OAuth | 完了 | 参加者ニックネーム単位でトークン保存。PWA の Account タブからログイン |

## 再生ロジック

| 要件 | 判定 | 実装 / 補足 |
|------|------|-------------|
| 曲追加後に全端末同期 | 完了 | `broadcast(.queueUpdated)`, `broadcast(.state)` |
| キュー先頭を自動再生 | 完了 | `JukeboxStore.playNext` |
| Apple Music 再生 | 完了 | `ApplicationMusicPlayer` |
| Spotify 曲指定再生 | 部分 | Spotify URI deep link。ホストアプリ内での完全制御は Spotify SDK / Premium / App 制約により未対応 |
| YouTube 曲指定再生 | 部分 | WKWebView を iOS/macOS の画面階層に配置。自動再生・長時間安定性は実機確認が必要 |
| サービス切替 1秒以内 | 部分 | 切替処理は実装。実測未実施。Spotify / YouTube は外部制約あり |
| 再生終了後の自動次曲 | 完了 | Apple Music 状態監視 / YouTube ended handler / 曲長推定 |

## 非機能

| 要件 | 判定 | 実装 / 補足 |
|------|------|-------------|
| 同時接続 5人 | 部分 | WebSocket クライアント管理あり。実測未実施 |
| 更新反映 300ms以内 | 部分 | WebSocket 即時配信 + 500ms progress。実測未実施 |
| Queue 同期 1秒未満 | 部分 | 即時配信設計。実測未実施 |
| 24時間稼働 | 部分 | スリープ抑止・ウォッチドッグあり。耐久試験未実施 |
| Wi-Fi 再接続復旧 | 完了 | `HostLifecycleManager` |
| 状態保持 | 完了 | `session` テーブル |

## すぐ使う場合の推奨運用

1. まず Apple Music メインで動作確認する。
2. Spotify は検索・プレイリスト追加用途として使い、再生は Spotify アプリへの遷移がある前提で扱う。
3. YouTube ログインは参加者が PWA の Account タブから行う（ニックネーム保存後）。
4. 参加者にはホスト画面の `http://<host-ip>:8765` を共有する。
5. 24時間常設前に Issue の耐久試験を実施する。
