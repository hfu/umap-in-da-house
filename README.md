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
- 起動/再起動: `sudo systemctl restart umap`
- 更新（標準手順）:
       1. `cd /opt/umap && git pull`
       2. `sudo -u www-data bash -lc "source /opt/umap/venv/bin/activate && python manage.py migrate --noinput"`
       3. `sudo -u www-data bash -lc "source /opt/umap/venv/bin/activate && python manage.py collectstatic --noinput"`
       4. `sudo systemctl restart umap`
- ログ: journald に集約（`journalctl -u umap`）

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
just install
```

セットアップが完了したら、ブラウザで http://hostname:8100/ にアクセスしてください。

> 💡 **Note**: `just install` は自動的にサービスを起動します。再起動が必要な場合は `just restart` を使用してください。

> 💡 **ネイティブインストール / Native Installation**: このプロジェクトは Docker を使用せず、Python 仮想環境と PostgreSQL/PostGIS をネイティブにインストールします。初回インストールには Raspberry Pi 4B で **約6分**かかります（パッケージが既にインストールされている場合。クリーンインストールの場合は追加で数分かかる可能性があります）。

## タスク一覧 / Available Tasks

| タスク | 説明 |
|--------|------|
| `just install` | 必要なパッケージのインストール、uMap のセットアップ、サービスの起動 |
| `just start` | uMap の起動 |
| `just stop` | uMap の停止 |
| `just restart` | uMap の再起動 |
| `just uninstall` | uMap の完全削除 |
| `just create-admin` | 管理者ユーザーの作成（対話式または非対話式） |
| `just shell` | Django シェルへのアクセス |
| `just tunnel` | Cloudflare Tunnel でインターネットに公開 |
| `just status` | サービスのステータス確認 |
| `just logs` | uMap ログの表示 |
| `just info` | システム情報の表示 |
| `just version` | バージョン情報の表示 |

## 詳細な使い方 / Detailed Usage

### インストール

```bash
just install
```

このコマンドは以下を実行します：
1. 必要なパッケージ（Python, PostgreSQL, PostGIS, git など）のインストール
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

### サービスの起動

```bash
just start
```

このコマンドは以下を実行します：
1. systemd サービスのリロード
2. uMap サービスの起動と有効化

> 💡 **Note**: `just install` は自動的にサービスを起動するため、初回インストール後にこのコマンドを実行する必要はありません。

起動には Raspberry Pi 4B で 1-2 分程度かかります。

### 管理者ユーザーの作成

**対話式（推奨）:**
```bash
just create-admin
```

**非対話式（自動化用）:**
```bash
just create-admin admin admin_password
```

Django の createsuperuser コマンドを実行して、管理者ユーザーを作成します。非対話式では、第1引数がユーザー名、第2引数がパスワードになります。

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
| `HTTP_PORT` | 8100 | 内部 HTTP ポート番号（gunicorn が 0.0.0.0:8100 でリスニング） |
| `SITE_URL` | http://localhost:8100 | uMap の公開 URL（地図共有リンクに使用） |
| `VENV_DIR` | /opt/umap/venv | Python 仮想環境ディレクトリ |
| `DB_NAME` | umap | PostgreSQL データベース名 |
| `DB_USER` | umap | PostgreSQL ユーザー名 |

## アーキテクチャ / Architecture

### スタンドアロンモード (Standalone Mode)

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │ :8100
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

アクセス先: `http://hostname:8100`

### nirokuとの共存モード (With niroku)

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │ :80
       ▼
┌─────────────┐
│    Caddy    │  (Reverse Proxy from niroku)
└──────┬──────┘
       │ /umap -> :8100
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

アクセス先: `http://hostname/umap`

- **Gunicorn**: Python WSGI サーバーとして uMap アプリケーションを実行 (0.0.0.0:8100 でリスニング)
- **uMap**: Django ベースの地図作成アプリケーション
- **PostgreSQL + PostGIS**: 地理空間データベース

すべてのコンポーネントがネイティブに動作し、systemd で管理されます。

## niroku との共存 / Integration with niroku

[niroku](https://github.com/unvt/niroku) がインストールされている環境では、Caddy を使用して uMap を `/umap` パスで公開できます。

### アーキテクチャ（詳細）

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │ :80
       ▼
┌─────────────────────────────────────┐
│    Caddy (niroku)                   │
│  ┌─────────────────────────────┐   │
│  │ /umap/static/* → File Server│   │  Static files from /opt/umap/static
│  │ /static/*      → File Server│   │  Direct static access
│  │ /umap/*        → :8100      │   │  App requests to gunicorn
│  └─────────────────────────────┘   │
└──────┬──────────────────────────────┘
       │ /umap/* (strip prefix)
       ▼
┌─────────────┐
│  Gunicorn   │  (0.0.0.0:8100)
│   + uMap    │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ PostgreSQL  │
│ + PostGIS   │
└─────────────┘
```

### Caddyfile の完全な設定例

`/opt/niroku/Caddyfile` の内容：

```caddyfile
:80 {
    # Add CORS headers to all responses
    header Access-Control-Allow-Origin "*"
    header Access-Control-Allow-Methods "GET, POST, OPTIONS"
    header Access-Control-Allow-Headers "*"

    # uMap static files (serve from /opt/umap, strip /umap prefix)
    handle /umap/static/* {
        root * /opt/umap
        uri strip_prefix /umap
        file_server
    }

    # Also handle requests to /static/* (some assets are absolute /static/...)
    handle /static/* {
        root * /opt/umap/static
        uri strip_prefix /static
        file_server
    }

    # uMap upload files
    handle /umap/uploads/* {
        root * /opt/umap
        uri strip_prefix /umap
        file_server
    }

    # uMap application (reverse proxy) - must come before general file_server
    handle_path /umap/* {
        reverse_proxy localhost:8100 {
            header_up X-Forwarded-Proto {http.request.scheme}
            header_up X-Forwarded-Host {http.request.host}
            header_up X-Forwarded-Port {http.request.port}
            header_up Host {http.request.hostport}
            header_up X-Forwarded-Prefix "/umap"
        }
    }

    # Finally serve niroku static data for any other requests
    root * /opt/niroku/data
    file_server
}
```

### 重要なポイント

1. **静的ファイルの配信**: Caddy が直接 `/opt/umap/static/` から静的ファイルを配信します。nginx は不要です。
2. **handle の順序**: 静的ファイルのハンドラを先に記述することで、アプリケーションより優先して処理されます。
3. **uri strip_prefix**: `/umap` プレフィックスを削除してから処理することで、アプリケーション側は通常のパスで動作します。

### SITE_URL の変更

niroku 経由でアクセスする場合は、`SITE_URL` を更新:

```bash
just --set SITE_URL "http://your-hostname/umap" install
```

または、既存の設定を変更:

```bash
sudo nano /etc/umap/settings.py
# SITE_URL と SHORT_SITE_URL を "http://your-hostname/umap" に変更
sudo systemctl restart umap
```

### Caddy の再起動

```bash
sudo systemctl restart caddy-niroku
```

これで以下のURLでアクセスできます：
- `http://your-hostname/` - サービス一覧ページ
- `http://your-hostname/umap/` - uMap アプリケーション
- `http://your-hostname/martin/` - Martin ベクタータイルサーバー（niroku に含まれる場合）

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

デフォルトでは gunicorn が8100番ポートでリスニングします。他のサービスが使用している場合：

```bash
# 使用中のポートを確認
sudo ss -tulpn | grep :8100

# 競合しているサービスを停止
sudo systemctl stop <service-name>
```

### 静的ファイルが読み込めない (404 エラー)

niroku/Caddy 経由でアクセスしている場合、静的ファイル（CSS/JS）が 404 エラーになる場合：

```bash
# 静的ファイルが存在するか確認
ls -la /opt/umap/static/umap/

# Caddyfile で静的ファイルのハンドラが正しく設定されているか確認
cat /opt/niroku/Caddyfile | grep -A 5 "handle /umap/static"

# Caddy を再起動
sudo systemctl restart caddy-niroku
```

**原因と解決策：**
- gunicorn は静的ファイルを配信しません
- Caddy で静的ファイルを直接配信する必要があります
- 上記の「niroku との共存」セクションの Caddyfile 設定を参照してください

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
