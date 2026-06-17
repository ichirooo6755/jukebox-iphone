# マルチストリーミング・ジュークボックス (iPhone / iPad)

民主的ジュークボックスの **Phase 1〜6** 実装です。常設 iPhone / iPad がホストとなり、参加者は同一 Wi-Fi 上の PWA からキューを編集します。

## 対応デバイス

| 項目 | 内容 |
|------|------|
| iOS | **16.0+**（iPhone 8 / SE 2 / XR 以降、iPad 6 世代以降） |
| 端末 | iPhone / iPad 両対応 |
| 音声出力 | **3.5mm ジャック** / Lightning・USB-C 変換アダプタ経由の有線出力（DAC 不要） |

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
| Apple Music 検索・再生 | ✅ |
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

1. Xcode で Signing Team を設定
2. 実機（iPhone / iPad）にインストール
3. **有線イヤホン or 3.5mm アダプタ**を接続
4. 「ホストを開始」をタップ
5. 参加者は `http://<ホストIP>:8765` を Safari で開く

### Spotify / YouTube（任意）

Xcode Scheme → Environment Variables に `.env.example` の値を設定。

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
├── Packages/JukeboxCore/  # API / DB / WebSocket
└── web/                   # 参加者 PWA
```

## 音声出力について

外部 DAC は使いません。`AVAudioSession` を `.playback` に設定し、接続されている出力先を自動検出します。

- 3.5mm ジャック（iPhone 6s〜SE 2 など）
- Lightning / USB-C → 3.5mm 変換アダプタ
- 内蔵スピーカー（有線未接続時）

## Phase 7（将来）

Raspberry Pi を制御サーバーとして追加し、`JukeboxCore` をそのまま流用可能な設計です。

## ライセンス

MIT
