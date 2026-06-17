# 参加者 UI の方針

## 結論

| UI | 対象 | 位置づけ |
|----|------|----------|
| **Web（PWA）** | Android / iPhone / タブレット / PC ブラウザ | **標準・メイン**。廃止しない |
| **JukeboxGuest** | iPhone / iPad のみ | **任意の iOS ネイティブ**。Web の代替ではない |

## なぜ Web を残すか

- **Android ユーザー**がいる（ネイティブ Guest は iOS のみ）
- **インストール不要**で QR スキャンだけで参加できる
- 多くの参加者にとって **ブラウザの方がわかりやすい**
- Spotify / YouTube の OAuth・プレイリスト・キュー操作は **Web で完結**

## JukeboxGuest を使う理由（任意）

- Apple Music **マイライブラリ**のプレイリスト（Web では不可）
- **Live Activity** / Dynamic Island / ロック画面表示
- ネイティブ OAuth（`jukeboxguest://`）

## 参加者への案内例

```
みんな: ホストの QR をスキャン → ブラウザで参加（Android も iPhone も同じ）

iPhone で Apple Music の自分のプレイリストを使いたい人だけ:
  App Store 的に JukeboxGuest を入れる（開発中は Xcode から）
```

## 技術

- ホストは `web/` フォルダをビルド時にバンドルし `http://<IP>:8765` で配信
- Guest も同じ REST API / WebSocket を利用（機能パリティを維持）
- 新機能は **Web 優先**で実装し、iOS 専用機能だけ Guest に追加する

## 関連

- Web UI: `web/`（`index.html`, `js/app.js`）
- Guest: `docs/GUEST_APP.md`
- Apple Music 制約: `docs/APPLE_MUSIC_PARTICIPANT.md`
