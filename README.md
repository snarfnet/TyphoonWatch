# 台風を観測

台風の進路、地点リスク、公式データ元をコンパクトに見られるiOSアプリです。

## 主なデータ元

- Digital Typhoon Mf-JSON: 西太平洋の台風軌跡
- 気象庁: 公式の台風情報、警報、ひまわり衛星
- NOAA NHC GIS: 予報円、風域、警戒域の参考
- JTWC: 西太平洋の英語警報
- JAXA GSMaP / NASA Worldview: 降水、衛星画像の参考

## 開き方

```bash
cd ios/TyphoonWatch
xcodegen generate
open TyphoonWatch.xcodeproj
```

`Digital Typhoon` に接続できない時は、アプリ内のサンプル台風で画面を維持します。

## GitHub Actions / TestFlight

`.github/workflows/typhoon-watch-testflight.yml` で、XcodeGen、archive、App Store Connect upload、TestFlight処理待ちまで実行します。

必要なGitHub Secrets:

- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_PRIVATE_KEY` または `ASC_API_KEY_CONTENT`
- `TYPHOON_WATCH_APP_ID`（App Store Connectにアプリ作成済みの場合）

手動実行はGitHub Actionsの `TyphoonWatch TestFlight Upload` からできます。`codex/typhoon-watch-testflight` ブランチへpushしても走ります。

App Store Connect App ID: `6775479428`

## 生成アセット

- `AppIcon.appiconset/AppIcon-1024.png`
- `TyphoonHeroBackdrop.imageset/typhoon-hero-backdrop.png`
- `RadarPanelTexture.imageset/radar-panel-texture.png`

すべてimagegenで作成した台風レーダー風のビジュアルです。アイコン、背景、カード内HUD素材として使っています。
