# uMap in-da-house 🏠🗺️

Raspberry Pi 上で [uMap](https://github.com/umap-project/umap) を簡単に立ち上げるための Justfile ベースのセットアップツール。

## 背景 / Background

このプロジェクトは、[geosight-in-da-house](https://github.com/hfu/geosight-in-da-house) のパターンを参考に、uMap を Raspberry Pi 環境で簡単に導入・稼働させるために作成されました。

uMap は OpenStreetMap ベースのオープンソース地図作成プラットフォームで、カスタム地図の作成と共有が可能です。本プロジェクトは、Raspberry Pi 上での uMap の稼働を簡単に行えるようにし、教育環境やエッジコンピューティングでの利用を促進します。

## 決定事項（方針）
- リポジトリ: `umap-in-da-house`
- 取得元: 本家 `umap-project/umap` をクローンして利用
- 環境変数: 簡易設定は `/etc/umap/settings.py` に一元管理（将来的に `/etc/umap/.env` を併用する想定）
- DB設計: 既定のまま（uMap の設計を尊重）
- HTTPS: 後回し（まずはローカルで HTTP を安定化）
- フロントエンド: 初回にビルドが必要な場合は一回だけに集約（uMap は多くが静的ファイルで配信される）

## 運用フロー（標準化）
- 起動/再起動: `sudo systemctl restart umap nginx`
- 更新（標準手順）:
       1. `cd /opt/umap && git pull`
       2. `sudo -u www-data bash -lc "source /opt/umap/venv/bin/activate && python manage.py migrate --noinput"`
       3. `sudo -u www-data bash -lc "source /opt/umap/venv/bin/activate && python manage.py collectstatic --noinput"`
       4. `sudo systemctl restart umap nginx`
- ログ: journald に集約（`journalctl -u umap`）、Nginx のアクセスログは必要に応じてオフ推奨

<!-- Removed: uWSGI comparison — keep stack focused on uMap runtime choices -->

## 既知の注意点
- 初回の `pip install` / `collectstatic` は時間がかかる（特に初回ビルド）
- PostGIS は apt でインストール（Raspberry Pi OS のパッケージ名に注意）
- データベースユーザーの権限チェックを `just install` に入れている（マイグレーション時の権限エラー対策）

## 特徴 / Features

- **ネイティブインストール**: Docker を使用せず、uMap 公式ドキュメントに従ったネイティブインストール
- **リソース効率**: Docker のオーバーヘッドがなく、Raspberry Pi のリソースを最大限活用
- **自動セットアップ**: `just doit` 一つで完全自動インストール
- **systemd 統合**: systemd サービスとして管理され、自動起動に対応

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

セットアップが完了したら、ブラウザで http://localhost/ にアクセスしてください。

> 💡 **ネイティブインストール / Native Installation**: このプロジェクトは Docker を使用せず、Python 仮想環境と PostgreSQL/PostGIS をネイティブにインストールします。初回インストールには 10-20 分程度かかります。

## タスク一覧 / Available Tasks

| タスク | 説明 |
|--------|------|
| `just install` | 必要なパッケージのインストールと uMap のセットアップ |
| `just run` | uMap の起動 |
| `just stop` | uMap の停止 |
| `just restart` | uMap の再起動 |
| `just uninstall` | uMap の完全削除 |
| `just doit` | install と run を続けて実行 |
| `just create-admin` | 管理者ユーザーの作成 |
| `just shell` | Django シェルへのアクセス |
| `just tunnel` | Cloudflare Tunnel でインターネットに公開 |
| `just status` | サービスのステータス確認 |
| `just logs` | uMap ログの表示 |
| `just logs-nginx` | nginx ログの表示 |
| `just info` | システム情報の表示 |
| `just version` | バージョン情報の表示 |

## 詳細な使い方 / Detailed Usage

### インストール

```bash
just install
```

このコマンドは以下を実行します：
1. 必要なパッケージ（Python, PostgreSQL, PostGIS, nginx, git など）のインストール
2. PostgreSQL の起動と設定
3. uMap 用データベースとユーザーの作成
4. PostGIS 拡張機能の有効化
5. uMap リポジトリのクローン
6. Python 仮想環境の作成
7. uMap とその依存関係のインストール
8. Django の設定ファイル作成
9. データベースマイグレーションの実行
10. 静的ファイルの収集
11. systemd サービスの作成
12. nginx の設定

### 起動

```bash
just run
```

このコマンドは以下を実行します：
1. systemd サービスのリロード
2. uMap サービスの起動と有効化
3. nginx の起動と有効化

起動には Raspberry Pi 4B で 1-2 分程度かかります。

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
just --set HTTP_PORT 3000 install

# カスタムディレクトリを使用
just --set UMAP_DIR /var/www/umap install
```

| 変数 | デフォルト値 | 説明 |
|------|-------------|------|
| `UMAP_DIR` | /opt/umap | uMap のインストールディレクトリ |
| `UMAP_VERSION` | 3.4.2 | uMap バージョン |
| `HTTP_PORT` | 8000 | 内部 HTTP ポート番号（nginx が 80 でリスンします） |
| `VENV_DIR` | /opt/umap/venv | Python 仮想環境ディレクトリ |
| `DB_NAME` | umap | PostgreSQL データベース名 |
| `DB_USER` | umap | PostgreSQL ユーザー名 |

## アーキテクチャ / Architecture

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │ :80
       ▼
┌─────────────┐
│    nginx    │  (Reverse Proxy)
└──────┬──────┘
       │ :8000
       ▼
┌─────────────┐
│  Gunicorn   │  (WSGI Server)
│   + uMap    │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ PostgreSQL  │
│ + PostGIS   │
└─────────────┘
```

- **nginx**: リバースプロキシとして動作し、静的ファイルを直接提供
- **Gunicorn**: Python WSGI サーバーとして uMap アプリケーションを実行
- **uMap**: Django ベースの地図作成アプリケーション
- **PostgreSQL + PostGIS**: 地理空間データベース

すべてのコンポーネントがネイティブに動作し、systemd で管理されます。

## ネイティブインストールの利点 / Benefits of Native Installation

- **低リソース使用**: Docker のオーバーヘッドがなく、メモリとCPUを節約
- **高速起動**: コンテナの起動時間がないため、サービスがすぐに利用可能
- **直接アクセス**: ログやファイルに直接アクセス可能
- **公式ドキュメント準拠**: uMap の公式インストール方法に従っているため、アップデートや問題解決が容易
- **Raspberry Pi に最適**: 限られたリソースを最大限活用

## セキュリティ / Security

### 本番環境での注意事項

本プロジェクトは開発・テスト目的で設計されています。本番環境で使用する場合は、以下の点に注意してください：

1. **SECRET_KEY**: インストール時に自動生成されますが、漏洩した場合は `/etc/umap/settings.py` で再生成してください
2. **管理者パスワード**: `just create-admin` で強力なパスワードを設定してください
3. **データベースパスワード**: デフォルトではユーザー名と同じです。本番環境では変更してください
4. **ファイアウォール**: 必要なポートのみを開放してください
5. **HTTPS**: 本番環境では Let's Encrypt などで HTTPS を設定してください

### Cloudflare Tunnel の注意

`just tunnel` で作成されるトンネルは一時的なもので、認証なしでアクセス可能です。長期運用や本番環境では、Cloudflare Zero Trust を使用してアクセス制御を設定してください。

## トラブルシューティング / Troubleshooting

### サービスが起動しない

```bash
# ステータス確認
just status

# ログ確認
just logs
```

### データベース接続エラー

```bash
# PostgreSQL が起動しているか確認
sudo systemctl status postgresql

# データベースが存在するか確認
sudo -u postgres psql -l | grep umap
```

### ポート競合

デフォルトでは nginx が80番ポートでリスンします。他のサービスが使用している場合：

```bash
# 使用中のポートを確認
sudo ss -tulpn | grep :80

# 競合しているサービスを停止
sudo systemctl stop apache2  # 例: Apache が動作している場合
```

## 出典・参考資料 / References

- **uMap**: https://github.com/umap-project/umap
- **uMap Documentation**: https://docs.umap-project.org/
- **uMap Installation Guide**: https://docs.umap-project.org/en/stable/install/
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
