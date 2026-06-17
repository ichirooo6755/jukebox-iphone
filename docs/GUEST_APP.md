# JukeboxGuest アプリ

参加者用 iOS / iPad ネイティブアプリ。**Web（PWA）の代替ではなく、iOS 向けの追加オプション**です。

- **Android / 手軽に参加したい人** → ホストの QR → **ブラウザ（Web）** を使ってください（`docs/PARTICIPANT_UI.md`）
- **iPhone で Apple Music マイライブラリや Live Activity が欲しい人** → このアプリ

Web PWA と同等の操作ができます。

## タブ構成（Web と同じ 4 タブ）

| タブ | 機能 |
|------|------|
| **ホーム** | Now Playing、ジャケット、プログレス、再生/スキップ、スキップ投票、ルーレット表示 |
| **検索** | Spotify / YouTube / Apple Music、曲・プレイリスト・URL インポート |
| **キュー** | 一覧、並び替え、削除 |
| **アカウント** | ホスト接続、ホスト自動発見、OAuth、同期メトリクス |

## Web にない Guest 独自機能

- **Apple Music マイライブラリ**（端末の MusicKit 許可）
- **Live Activity** — ロック画面と Dynamic Island に再生状態を表示（iOS 16.2+、設定で許可が必要）
- **ネイティブ OAuth**（`jukeboxguest://`）

## リアルタイム同期

- WebSocket `/ws` でホストと同期（手動リフレッシュ不要）
- 接続バッジでオンライン状態を表示

## ビルド・インストール

```bash
xcodegen generate
# Xcode で JukeboxGuest スキーム → 実機 or シミュレータ
```

## 初回起動

1. オンボーディングでホスト URL 入力 or「ホストを探す」
2. Account で Spotify / YouTube ログイン（任意）
3. Search → Apple Music で端末許可（Apple ユーザー向け）

## Live Activity

ホスト接続後、再生中の曲がロック画面と Dynamic Island（対応機種）に表示されます。  
iPhone の **設定 → Jukebox Guest → ライブアクティビティ** で ON にしてください。

## 関連

- ホスト側 HDMI 設定: `docs/HOST_DISPLAY.md`
- Apple Music 参加者ガイド: `docs/APPLE_MUSIC_PARTICIPANT.md`
