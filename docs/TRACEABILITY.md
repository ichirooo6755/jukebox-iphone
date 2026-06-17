# 要件トレーサビリティ

`README.md` の要件定義書 v4.0 セクションと実装の突合表。2026-06-17 更新。

## 判定

| 判定 | 意味 |
|------|------|
| 完了 | コード上の機能実装あり。ビルド対象に含まれる |
| 制約 | プラットフォーム/API 制約により代替実装 |
| 未完 | 未実装または将来フェーズ |

## システム構成

| 要件 | 判定 | 実装 / 補足 |
|------|------|-------------|
| 参加者 3〜5人が同一キューを共有 | 完了 | `JukeboxStore`, `JukeboxServer`, PWA |
| Apple Music / Spotify / YouTube 混在キュー | 完了 | `MusicService`, `QueueItem`, Web UI のサービス選択 |
| リアルタイム同期 | 完了 | `/ws`, `JukeboxWebSocketHandler` |
| iPhone only 初期構成 | 完了 | `JukeboxHost` |
| Mac ホスト | 完了 | `JukeboxHostMac` |
| Raspberry Pi hybrid | 未完 | Phase 7。`pi-server/` v0.2 スキャフォールド |

## 参加者 UI

| 要件 | 判定 | 実装 / 補足 |
|------|------|-------------|
| Home: Now Playing 表示 | 完了 | `web/index.html`, `web/js/app.js` |
| Search: Apple Music / Spotify / YouTube | 完了 | `/api/search`, `SearchCoordinator` |
| Search: プレイリスト | 完了 | `/api/playlists`, `/api/playlists/import` |
| Queue: 表示 / 削除 / 並び替え | 完了 | PWA drag & drop、REST API |
| Queue: Skip vote | 完了 | `/api/playback/vote-skip`, `skip_votes` |
| Account: ログイン状態表示 | 完了 | `/api/auth/status` |
| 自動ホスト発見 | 完了 | `/api/discover` + PWA「ホストを探す」（Bonjour `Jukebox.local`） |
| ゲストネイティブアプリ | 完了 | `JukeboxGuest` + OAuth コールバック `jukeboxguest://` |

## 常設表示 UI

| 要件 | 判定 | 実装 / 補足 |
|------|------|-------------|
| 大きいジャケット / 曲名 / アーティスト | 完了 | `NowPlayingQueueView` |
| プログレスバー | 完了 | `NowPlayingQueueView`, `PlaybackEngine` |
| Next Queue 3〜5曲 | 完了 | `NowPlayingQueueView` |
| Wi-Fi 状態 | 完了 | `HostSetupView`, `HostServerStatus` |
| サービス接続状態 | 完了 | PWA Account とホスト画面のステータスバッジに表示 |
| ビジュアライザ | 追加実装 | `VisualizerView` |
| 耐久・メトリクス | 完了 | `HostDurabilitySheet`, `/api/metrics` |

## 認証 / サービス連携

| 要件 | 判定 | 実装 / 補足 |
|------|------|-------------|
| Apple Music 楽曲検索 | 完了 | `AppleMusicSearchService.search` |
| Apple Music プレイリスト取得 | 完了 | カタログプレイリストとホスト端末のライブラリプレイリストを検索 |
| Apple Music 各ユーザー認証 | 制約 | ホスト端末の MusicKit 認証を共有 |
| Spotify OAuth | 完了 | 参加者ごと `OAuthTokenStore` |
| Spotify 検索 / プレイリスト同期 | 完了 | Spotify Web API |
| OAuth トークン永続化 | 完了 | Spotify / YouTube のユーザートークンをローカルに保持 |
| YouTube API Key | 完了 | API Key 利用可。未設定でも OAuth ログイン後は検索できるよう補完 |
| YouTube OAuth | 完了 | 参加者ニックネーム単位でトークン保存 |

## 再生ロジック

| 要件 | 判定 | 実装 / 補足 |
|------|------|-------------|
| 曲追加後に全端末同期 | 完了 | `broadcast(.queueUpdated)`, `broadcast(.state)` |
| キュー先頭を自動再生 | 完了 | `JukeboxStore.playNext` |
| Apple Music 再生 | 完了 | `ApplicationMusicPlayer` |
| Spotify 曲指定再生 | 制約 | Spotify URI deep link |
| YouTube 曲指定再生 | 完了 | WKWebView + IFrame API 進捗・エラー・終了ハンドラ |
| プレイリストルーレット | 完了 | `playNextFromRoulette`, git-tree UI |
| サービス切替 1秒以内 | 完了 | 切替処理実装 + `/api/metrics` で遅延可視化 |
| 再生終了後の自動次曲 | 完了 | Apple Music 状態監視 / YouTube ended handler / 曲長推定 |

## 非機能

| 要件 | 判定 | 実装 / 補足 |
|------|------|-------------|
| 同時接続 5人 | 完了 | WebSocket クライアント管理 + metrics 表示 |
| 更新反映 300ms以内 | 完了 | WebSocket 即時配信 + PWA 往復遅延表示 |
| Queue 同期 1秒未満 | 完了 | 即時配信設計 + metrics |
| 24時間稼働 | 完了 | スリープ抑止・ウォッチドッグ・セルフテスト API（実機24h記録は手動） |
| Wi-Fi 再接続復旧 | 完了 | `HostLifecycleManager` |
| 状態保持 | 完了 | `session` テーブル |

## すぐ使う場合の推奨運用

1. まず Apple Music メインで動作確認する。
2. Spotify は検索・プレイリスト追加用途として使い、再生は Spotify アプリへの遷移がある前提で扱う。
3. YouTube ログインは参加者が PWA / JukeboxGuest の Account タブから行う。
4. 参加者は QR、IP 直打ち、または Account の「ホストを探す」を使う。
5. 常設前にホストメニュー「耐久・メトリクス」でセルフテストを実行する。
