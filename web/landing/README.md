# Jukebox 参加ランディング（Netlify）

参加者が QR コードを読み取ったとき、まずこの常設ページを経由して LAN 内のホストへリダイレクトします。

## 本番 URL

https://jukebox-join-ichirooo6755.netlify.app

QR の実際の URL 例:

```
https://jukebox-join-ichirooo6755.netlify.app/?host=http://192.168.43.8:8765
```

ホストアプリは `JUKEBOX_JOIN_URL` が設定されている場合、QR に上記形式の URL を自動生成します。

## デプロイ

```bash
cd jukebox-iphone
./scripts/deploy-landing.sh
```

初回は Netlify CLI のログインが必要です（`netlify login`）。

## ホスト側の設定

`Secrets.plist` または `.env` に以下を設定:

```
JUKEBOX_JOIN_URL=https://jukebox-join-ichirooo6755.netlify.app
```

## 動作フロー

1. 参加者が QR をスキャン → Netlify ランディングを開く
2. `host` パラメータの LAN URL へ自動リダイレクト（`/?join=1` 付き）
3. PWA で名前入力（空白なら `guest-番号`）→ 各サービスにログイン or Skip
