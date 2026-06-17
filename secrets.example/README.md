# Secrets（認証情報の置き場）

このフォルダに OAuth 認証ファイルを置きます。**Git には含めません**（`.gitignore` 済み）。

## 手順

1. `secrets.example/` のテンプレートをコピー:

```bash
cp secrets.example/spotify_auth.json secrets/spotify_auth.json
cp secrets.example/google_auth.json secrets/google_auth.json
```

2. 各ファイルに Spotify / Google Cloud の値を記入

3. アプリへ反映:

```bash
./scripts/import-auth-files.sh
```

## ファイル一覧

| ファイル | 内容 |
|----------|------|
| `spotify_auth.json` | Spotify Client ID / Secret |
| `google_auth.json` | Google Cloud からダウンロードした OAuth クライアント JSON（`client_secret_....json` をこの名前で保存） |
| `notes.md` | 任意のメモ（コミットしない） |
