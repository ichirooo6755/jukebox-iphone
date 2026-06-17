# Jukebox タスク台帳

このファイルは**削除しない**。ユーザー指示を具体的に記録し、実装済みかどうかを永続的に残す。

凡例: ✅ 完了 / 🟡 一部完了 / ⬜ 未着手

---

## 過去の指示（確認・修正済み）

| # | 内容 | 状態 | メモ |
|---|------|------|------|
| 1 | Phase 6 までの実装確認・バグ修正 | ✅ | DB デッドロック、OAuth、プレイリスト API、PWA UI |
| 2 | OAuth Redirect URI（HTTPS Netlify 経由） | ✅ | `web/landing/oauth/callback.html` |
| 3 | QR 1回の参加フロー | ✅ | `http://<IP>:8765` 直開き |
| 4 | サービスログインを2回聞かない（Account のみ） | ✅ | commit `4c2a049` |
| 5 | オンボード画面が閉じない問題 | ✅ | 名前入力のみ、OAuth 後は Account 復帰 |
| 6 | アルバムカバー表示 | ✅ | `/api/artwork` プロキシ + MusicKit フォールバック |
| 7 | Web UI 再生ボタン | ✅ | Home タブに再生/スキップ |
| 8 | 曲追加トースト通知 | ✅ | `showToast()` |
| 9 | ホスト起動時にサーバー自動開始 | ✅ | `AppModel.bootstrap()` |
| 10 | Apple Music 統合検索（曲/プレイリスト/アーティスト） | ✅ | `/api/search/unified` |

---

## 今回の指示（2026-06-17）

| # | 内容 | 状態 | メモ |
|---|------|------|------|
| 11 | これまでの機能・問題ができているか確認 | ✅ | 本ファイル + README 更新 |
| 12 | コードのおかしいところを整理 | ✅ | VolumeSlider 接続、参加者 OAuth 分離、Form UI |
| 13 | ログイン情報を残す（Google 名、Spotify 等） | ✅ | OAuth 後に display_name / avatar_url を UserDefaults + localStorage に保存 |
| 14 | **一曲ずつモード**（現状のキュー） | ✅ | `single_track` |
| 15 | **プレイリスト選択モード**（ルーレット） | ✅ | API・再生・PWA/ホスト git-tree UI |
| 16 | 複数人プレイリストを 1/N ルーレットで抽選 | ✅ | `playNextFromRoulette()` |
| 17 | git tree 風 UI（ユーザー名横並び・進捗表示） | ✅ | PWA + `PlaylistGraphView`（ホスト） |
| 18 | 長い曲名のマーキー表示 | ✅ | `.marquee.scroll`（はみ出すときのみ） |
| 19 | 各サービスからプレイリストインポート | ✅ | 検索 + 共有 URL 直貼り（`PlaylistURLParser`） |
| 20 | 活用できそうな API の調査・案内 | ✅ | README / 本ファイル末尾 |
| 21 | 常設デバイスの音声出力選択（3.5mm/BT/AirPlay） | ✅ | iOS: `AVRoutePickerView`、Mac: 既定デバイス名 + サウンド設定 |
| 22 | README にプロジェクト説明を先頭に | ✅ | 「このプロジェクトについて」セクション |
| 23 | todo.md を消さず永続管理 | ✅ | 本ファイル |

---

## 追加指示（2026-06-17 続き）

| # | 内容 | 状態 | メモ |
|---|------|------|------|
| 24 | ゲスト側ネイティブアプリ | ✅ | `JukeboxGuest` + `ASWebAuthenticationSession` OAuth |
| 25 | ラズパイ構成の検討（Zero W / 2W / 3B） | ✅ | `docs/RASPBERRY_PI.md` + `pi-server/` v0.2 |
| 26 | UI のさらなる改善（ホスト SwiftUI を Apple 公式寄り） | ✅ | `HostSetupView` を Form + NavigationStack に |
| 27 | プレイリスト共有 URL を貼るだけでインポート | ✅ | PWA + Guest + `/api/playlists/resolve-url` |
| 28 | プレイリストルーレットの途中参加マージ UI | ✅ | `branch` / `途中参加` 表示（PWA + ホスト） |
| 29 | Spotify を参加者ごとに分離 | ✅ | `OAuthTokenStore` の participant キー分離 |
| 30 | ホスト画面にもプレイリストグラフ表示 | ✅ | `NowPlayingQueueView` + `PlaylistGraphView` |
| 31 | Phase 6 実機耐久（24h・Wi-Fi 復旧） | ✅ | API・セルフテスト・`HostDurabilitySheet`（24h 実機記録は手動） |
| 32 | PWA ホスト自動発見 | ✅ | `/api/discover` + Account「ホストを探す」 |
| 33 | 同期メトリクス実測表示 | ✅ | `/api/metrics` + PWA Account 往復遅延 |

---

## プラットフォーム制約（実装不可・代替運用）

| 項目 | 状態 | 補足 |
|------|------|------|
| 参加者ごとの Apple Music 認証 | 制約 | MusicKit はホスト共有のみ |
| Spotify ホスト内ネイティブ再生 | 制約 | deep link 運用（SDK / Premium 制約） |

---

## 活用できそうな API（プレイリスト共有・取得）

### Spotify
- `GET /v1/me/playlists` — ログイン済みユーザーのプレイリスト一覧
- `GET /v1/playlists/{id}` + `GET /v1/playlists/{id}/tracks` — ID が分かれば共有 URL からも取得可
- `playlist-read-collaborative` — 共同プレイリスト
- 共有: `spotify:playlist:{id}` / `https://open.spotify.com/playlist/{id}`

### YouTube / Google
- `playlists.list`（`mine=true`）— OAuth ログイン済みの自分のプレイリスト
- `playlistItems.list` — プレイリスト内の動画
- 共有: `https://www.youtube.com/playlist?list={playlistId}` を URL パースして ID 抽出
- `userinfo` / `openid` — 表示名・アイコン（実装済み）

### Apple Music（ホスト MusicKit）
- `MusicCatalogResourceRequest<Playlist>` — カタログ検索
- `MusicLibraryRequest<Playlist>` — ホスト端末のライブラリ（要許可）
- 参加者個別ログインは MusicKit 制約上不可。ホスト共有のまま

### 間接連携（参考）
- **Soundiiz / TuneMyMusic** — サービス間プレイリスト移行（公式 API ではない）
- **Spotify Embed / oEmbed** — 表示用。キュー操作には不向き
- **Apple Music Marketing Tools** — リンク生成のみ

---

## 旧メモ（アーカイブ）

1. ゲスト側のアプリを作成する。→ #24 ✅
2. ラズパイを有効活用する構成を考えて使用する。→ #25 ✅
3. UIの改善 → #26 ✅
