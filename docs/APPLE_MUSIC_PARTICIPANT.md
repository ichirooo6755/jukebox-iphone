# Apple Music 参加者ガイド

## 結論

| やりたいこと | Web (PWA) | JukeboxGuest (iOS) |
|-------------|-----------|---------------------|
| カタログ曲・プレイリスト検索 | ✅ ホストの MusicKit で検索 | ✅ 同上（ホスト経由） |
| **自分のマイライブラリ**プレイリスト | ❌ 不可 | ✅ **この端末で Apple Music 許可** |
| ホストでの再生 | ✅ 曲 ID を送信 | ✅ 曲 ID を送信 |

**Web をネイティブアプリに置き換えるだけでは、参加者ごとの Apple Music ライブラリにはアクセスできません。**  
PWA のブラウザからは MusicKit の個人ライブラリ API が使えないためです。

**JukeboxGuest** では、参加者の iPhone 上で `MusicAuthorization.request()` し、マイライブラリのプレイリストを読み取ってホストに曲 ID 一覧を送ります。再生はホストの MusicKit が担当します。

## 他サービスから Apple Music へ移行したプレイリスト

Soundiiz / TuneMyMusic などで Spotify → Apple Music に移行した場合:

1. 移行ツールで Apple Music にプレイリストを取り込む
2. **JukeboxGuest** の Search → Apple Music →「Apple Music を許可」
3. マイプレイリストから選んでホストに追加

Jukebox 内に移行ツールは組み込みません（外部サービスの利用を想定）。

## Spotify / YouTube

- **Spotify**: Account でログイン（参加者ごと）→ Search で「自分のプレイリスト」または URL 貼り付け
- **YouTube**: Account でログイン（参加者ごと）→ Search で「自分のプレイリスト」または URL 貼り付け

## API

- `GET /api/playlists/mine?service=spotify|youtube` — ログイン済み参加者のプレイリスト一覧
- `POST /api/playlists/import-tracks` — Guest が端末で取得した曲一覧を直接インポート（Apple Music 用）
