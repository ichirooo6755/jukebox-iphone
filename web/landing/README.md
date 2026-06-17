# OAuth コールバック中継（Netlify）

LAN 内の `http://192.168.x.x` は Spotify / Google の OAuth Redirect URI として使えないため、HTTPS のこのページを登録します。

## Redirect URI（Spotify / Google 共通）

```
https://jukebox-join-ichirooo6755.netlify.app/oauth/callback.html
```

## 動作

1. 参加者がホストの `/api/auth/{service}/start` へアクセス
2. Spotify / Google へ HTTPS Redirect URI で認証
3. この Netlify ページが `code` と `state` を受け取る
4. `state` 内のホスト IP へ LAN コールバックへ転送
5. ホストがトークン交換してログイン完了

## デプロイ

```bash
cd jukebox-iphone
./scripts/deploy-landing.sh
```

## ホスト設定

`.env` / `Secrets.plist`:

```
OAUTH_PUBLIC_REDIRECT_URI=https://jukebox-join-ichirooo6755.netlify.app/oauth/callback.html
```
