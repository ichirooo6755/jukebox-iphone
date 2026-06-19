# ホスト表示・出力設定

常設 iPhone / iPad / **Mac** をホストとして使うときの、QR・HDMI・音声の設定ガイド。

## 参加用 QR コード

- **セットアップ画面**と**稼働中のパーティー画面**に QR を表示
- 稼働中は画面**右下に QR を常駐**（`HostPersistentQRPanel`）。タップで拡大シート
- 参加者 URL は **サーバー起動時の IP で固定**
- Wi-Fi を変更したときだけ、ホスト画面の **「Wi-Fi 変更後に QR を更新」** で再取得
- QR の中身: `http://<LAN-IP>:8765`（mDNS `Jukebox.local` はフォールバック表示）
- 参加者は Web PWA または **JukeboxGuest** で開く
- **Mac ホスト**: Scheme `JukeboxHostMac`（macOS 14+）。QR コピーはメニューからも可能

> 常設中に QR / URL が勝手に切り替わると参加者が切断されるため、定期更新はしません。

### テザリング / インターネット共有

同一 Wi-Fi が使えない場合は、ホストのテザリング IP（例: `172.20.10.x`）を参加者に直接入力。mDNS は失敗しやすいため LAN IP 表示を参照。

## パーティー画面レイアウト（Now Playing）

- **左**: アルバムアート + **その直下に再生バー**（進捗・経過時間）
- **右**: 曲情報・キュー・音量（ワイド画面時）
- 背景はジャケット画像のぼかし

## HDMI / 外部ディスプレイ（映像・iOS のみ）

iPhone / iPad を HDMI アダプタや USB-C ディスプレイに接続すると:

1. **「HDMI にパーティー画面を表示」** — 外部画面に Now Playing + キュー UI
2. **「接続時はこの端末を操作パネルに」** — 本体画面は QR・再生操作・設定のみ

外部ディスプレイには `NowPlayingQueueView`（パーティー向け大画面）を出力します。

## 音声出力（HDMI とは別）

- 映像: HDMI / 外部ディスプレイ（iOS）
- 音声: **AVRoutePickerView**（iOS）または Mac の既定出力デバイス
- `prioritizesVideoDevices = false` により、AirPlay メニューは音声向け

### おすすめ構成

| 用途 | 設定 |
|------|------|
| パーティー | HDMI → テレビ（映像のみ）、Bluetooth スピーカー → 音声 |
| 常設 Mac | 内蔵スピーカー / 有線 / Bluetooth |
| 常設 iOS | 有線スピーカー or 3.5mm、本体画面は操作パネル |

## 画面消灯・電源（iOS）

サーバー稼働中は以下が有効:

- `UIApplication.isIdleTimerDisabled = true` — 画面が自動で消えない
- `UIBackgroundModes: audio` — 再生継続
- `UIRequiresPersistentWiFi` — Wi-Fi 維持

バッテリー運用時は充電を推奨。

## 技術メモ

- `UIApplicationSupportsMultipleScenes = true`（外部ディスプレイ用・iOS）
- `ExternalDisplayManager` が `UIWindowScene`（外部）を監視
- DEBUG ビルドではリポジトリの `web/` を優先配信（古いバンドル回避）
- ホスト Apple ID は再生専用アカウント推奨（おすすめ汚染防止）

## 関連 issue

- **#3** Mac ホスト: `JukeboxHostMac` で対応済み
- **#5** リモート参加: `relay-server` + `RELAY_BASE_URL`（`docs/REMOTE_JOIN.md`）
