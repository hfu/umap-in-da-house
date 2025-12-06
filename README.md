# uMap in-da-house 🏠🗺️

Raspberry Pi 上で [uMap](https://github.com/umap-project/umap) を簡単に立ち上げるための Justfile ベースのセットアップツール。

## 背景 / Background

このプロジェクトは、[geosight-in-da-house](https://github.com/hfu/geosight-in-da-house) のパターンを参考に、uMap を Raspberry Pi 環境で簡単に導入・稼働させるために作成されました。

uMap は OpenStreetMap ベースのオープンソース地図作成プラットフォームで、カスタム地図の作成と共有が可能です。本プロジェクトは、Raspberry Pi 上での uMap の稼働を簡単に行えるようにし、教育環境やエッジコンピューティングでの利用を促進します。

## 対応環境 / Supported Environment

- **OS**: Raspberry Pi OS trixie (Debian 13) 64-bit
- **Hardware**: Raspberry Pi 4B (4GB RAM 推奨、最低 2GB)
- **Storage**: 16GB 以上の microSD カードまたは SSD

## 前提条件 / Prerequisites

- Raspberry Pi OS trixie 64-bit がインストール済み
- インターネット接続
- [just](https://github.com/casey/just) コマンドラインランナー

> 💡 **Tip**: [niroku](https://github.com/unvt/niroku) を事前に導入している場合、just は既にインストールされているため、以下のインストール手順をスキップできます。

### just のインストール

```bash
# Debian/Raspberry Pi OS
sudo apt-get update
sudo apt-get install -y just

# または、公式リリースからインストール
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin
```

## クイックスタート / Quick Start

```bash
# リポジトリをクローン
git clone https://github.com/hfu/umap-in-da-house.git
cd umap-in-da-house

# インストールと起動を一度に実行
just doit
```

> ⚠️ **注意 / Note**: 初回インストール時に Docker グループへの追加が必要な場合、`just install` が途中で終了します。その場合は、ログアウト・ログインして `just build-umap` と `just run` を実行してください。

> 💡 **ARM64 専用ビルド / ARM64-specific Build**: このプロジェクトは ARM64 (Raspberry Pi) 向けに最適化されています。`just doit` は自動的に uMap イメージを ARM64 向けにビルドします。初回ビルドには 10-30 分程度かかります。

セットアップが完了したら、ブラウザで http://localhost:8000/ にアクセスしてください。

## タスク一覧 / Available Tasks

| タスク | 説明 |
|--------|------|
| `just install` | 必要なパッケージのインストールと uMap のセットアップ |
| `just build-umap` | ARM64 向け uMap Docker イメージのビルド (必須) |
| `just run` | uMap の起動 |
| `just stop` | uMap の停止 |
| `just restart` | uMap の再起動 |
| `just uninstall` | uMap の完全削除 |
| `just doit` | install, build-umap, run を続けて実行 |
| `just create-admin` | 管理者ユーザーの作成 |
| `just shell` | Django シェルへのアクセス |
| `just tunnel` | Cloudflare Tunnel でインターネットに公開 |
| `just status` | コンテナのステータス確認 |
| `just health` | サービスのヘルスチェック |
| `just logs` | 全ログの表示 |
| `just logs-app` | アプリケーションログのみ表示 |
| `just clean` | 未使用の Docker リソースを削除 |
| `just info` | システム情報の表示 |
| `just version` | バージョン情報の表示 |

## 詳細な使い方 / Detailed Usage

### インストール

```bash
just install
```

このコマンドは以下を実行します：
1. 必要なパッケージ（docker.io, docker-compose, curl, openssl, python3）のインストール
2. Docker サービスの有効化と起動
3. 現在のユーザーを docker グループに追加
4. uMap 用の docker-compose.yml と nginx.conf の生成

### uMap イメージのビルド (ARM64)

```bash
just build-umap
```

このコマンドは以下を実行します：
1. uMap の公式リポジトリをクローン (指定されたバージョン)
2. Docker buildx を使用して ARM64 向けにイメージをビルド
3. ローカルに `umap-in-da-house/umap:3.4.2-arm64` としてタグ付け

> ⚠️ **重要 / Important**: このステップは ARM64 デバイスで必須です。uMap の公式イメージは ARM64 版が提供されていないため、ローカルでビルドする必要があります。初回ビルドには Raspberry Pi 4B で 10-30 分程度かかります。

### 起動

```bash
just run
```

このコマンドは以下を実行します：
1. uMap イメージが存在するか確認（なければエラー）
2. その他の Docker イメージ（Redis, PostGIS, Nginx）のプル
3. Docker コンテナの起動
4. データベースマイグレーションの実行
5. 静的ファイルの収集

起動には Raspberry Pi 4B で 5-10 分程度かかる場合があります。

### 管理者ユーザーの作成

```bash
just create-admin
```

Django の createsuperuser コマンドを実行して、管理者ユーザーを作成します。

### Cloudflare Tunnel による公開

```bash
just tunnel
```

Cloudflare Tunnel を使用して uMap をインターネットに公開します。

## 設定パラメータ / Configuration Parameters

Justfile の変数は `just --set` で上書きできます：

```bash
# カスタムポートで起動
just --set HTTP_PORT 3000 run

# カスタム uMap バージョンを使用
just --set UMAP_VERSION 3.4.0 install
```

| 変数 | デフォルト値 | 説明 |
|------|-------------|------|
| `UMAP_DIR` | umap | uMap のディレクトリ名 |
| `HTTP_PORT` | 8000 | HTTP ポート番号 |
| `UMAP_VERSION` | 3.4.2 | uMap バージョン |
| `POSTGIS_IMAGE` | kartoza/postgis | PostGIS Docker イメージ名 |
| `POSTGIS_TAG` | 18-3.6--v2025.11.24 | PostGIS Docker イメージタグ |
| `UMAP_IMAGE` | umap-in-da-house/umap | uMap Docker イメージ名（ローカルビルド） |
| `UMAP_TAG` | 3.4.2-arm64 | uMap Docker イメージタグ（ARM64） |
| `COMPOSE_HTTP_TIMEOUT` | 300 | Docker Compose HTTP タイムアウト（秒） |
| `DOCKER_CLIENT_TIMEOUT` | 300 | Docker クライアントタイムアウト（秒） |

## ARM64 最適化 / ARM64 Optimization

このプロジェクトは ARM64 アーキテクチャ（Raspberry Pi 4B）向けに最適化されています：

- **ネイティブ ARM64 サポート**: すべての Docker イメージは ARM64 ネイティブで動作し、エミュレーションによる速度低下を回避します
- **PostGIS**: `kartoza/postgis:18-3.6--v2025.11.24` を使用（ARM64 対応の最新版）
- **uMap**: ローカルで ARM64 向けにビルド（公式イメージは ARM64 未対応のため）
- **プラットフォーム指定**: docker-compose.yml で `platform: linux/arm64` を明示的に指定

## セキュリティ / Security

### 本番環境での注意事項

本プロジェクトは開発・テスト目的で設計されています。本番環境で使用する場合は、以下の点に注意してください：

1. **SECRET_KEY**: インストール時に自動生成されますが、漏洩した場合は再生成してください
2. **管理者パスワード**: `just create-admin` で強力なパスワードを設定してください
3. **ファイアウォール**: 必要なポートのみを開放してください
4. **HTTPS**: 本番環境では HTTPS を設定してください

### Cloudflare Tunnel の注意

`just tunnel` で作成されるトンネルは一時的なもので、認証なしでアクセス可能です。長期運用や本番環境では、Cloudflare Zero Trust を使用してアクセス制御を設定してください。

## 出典・参考資料 / References

- **uMap**: https://github.com/umap-project/umap
- **uMap Documentation**: https://docs.umap-project.org/
- **uMap Docker Hub**: https://hub.docker.com/r/umap/umap
- **geosight-in-da-house**: https://github.com/hfu/geosight-in-da-house
- **just Command Runner**: https://github.com/casey/just
- **Cloudflare Tunnel**: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/

## 謝辞 / Acknowledgments

- **uMap Project** - uMap の開発と公開
- **OpenStreetMap** - 地図データの提供
- **geosight-in-da-house** - in-da-house パターンの確立

## ライセンス / License

このプロジェクトは CC0 1.0 Universal (パブリックドメイン) の下で公開されています。

**重要な注意事項 / Important Notes:**

- **本プロジェクトの範囲**: このリポジトリは、uMap を Raspberry Pi 上で起動するための自動化スクリプト（Justfile）とドキュメントのみを含みます。
- **uMap のライセンス**: uMap 本体は [WTFPL](https://github.com/umap-project/umap/blob/master/LICENSE) の下でライセンスされています。

---

Made with ❤️ by [hfu](https://github.com/hfu) and GitHub Copilot
