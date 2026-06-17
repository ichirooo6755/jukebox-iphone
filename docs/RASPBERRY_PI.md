# ラズパイ構成ガイド

## 推奨構成（Phase 7）

| 役割 | デバイス | 推奨モデル |
|------|----------|------------|
| コントロールサーバー | Raspberry Pi | **Zero 2 W** 以上（Zero W はメモリ不足の可能性） |
| 再生エンジン | 常設 iPhone / iPad / Mac | 現状どおり |

## なぜ Zero 2 W 以上か

- Zero W (512MB): HTTP + WebSocket + SQLite は可能だが、複数参加者でメモリ逼迫の恐れ
- **Zero 2 W (512MB, 4コア)**: 軽量コントロールサーバーに最適
- **3B / 4**: 将来の Pi 単体再生や Redis キャッシュを検討する場合

## 現状（2026-06）

- **再生はホスト iPhone/Mac が担当**（MusicKit / Spotify deep link / YouTube）
- Pi はキュー・WebSocket・OAuth 中継のみを担う設計（`pi-server/` 参照）
- 参加者は PWA または **JukeboxGuest** ネイティブアプリ

## 移行手順（将来）

1. Pi に `pi-server` を systemd で常駐
2. ホストアプリの `JUKEBOX_REMOTE_SERVER` を Pi の URL に設定
3. 再生専用 iPhone は `PlaybackEngine` のみ起動

## ネットワーク

- Pi とホスト・参加者は同一 LAN
- mDNS (`jukebox.local`) または固定 IP 推奨
