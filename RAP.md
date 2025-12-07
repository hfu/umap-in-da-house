# uMap in-da-house RAP 🎤

Hook:

uMap in da house, flip it native,
Pi の心臓で走る、軽くて熱いデプロイ、
PostGIS は apt で通す、静的は一度で固める、
現場で最新を浴びて、まずは試してみる。

Verse 1: Decisions

本家をクローン、公式に準拠、簡潔に走る、
設定は `/etc/umap/settings.py` に一元、秘密はそこへ、
HTTPS は後回し、まずはローカルで動くこと、
DB は与えられた設計を尊重、権限は確実に与える。

Pre-Chorus: Build & Cache

npm や pip は初回に時間を使う、キャッシュで二度目を速く、
collectstatic は確実に実行、manifest を壊さない。

Chorus: Ops flow

git pull、migrate、collectstatic、再起動で締める、
journald にログを集め、nginx の access_log は必要に応じてオフ、
gunicorn でまずは軽く走らせ。

Bridge: Struggle & Evolution (Dec 2025)

nginx on :80 が niroku と衝突、ポート変えて 8100 へ、
でも静的ファイルが 404、gunicorn は静的を配らない、
「nginx 戻すか？」迷いの中、"simpler is better" を掲げ、
Caddy に統合、一つの Webサーバーで niroku と共存へ。

`handle_path` の順序を学び、`strip_prefix` でパスを剥ぎ、
`/umap/static/*` と `/static/*` の両方をハンドル、
リバースプロキシに `X-Forwarded-Prefix` を追加し、
試行錯誤の末、静的ファイルが光る、302 が返る、uMap が息を吹き返す。

失敗から学び、苦心して乗り越え、自信と誇りを取り戻す、
それが RAP の精神、エンジニアリングの本質。

Verse 2: Pi の限界を知る

メモリと I/O に余白をもたせる、SSD があるなら使う、
サービスは最小限で、監視は軽く、レスポンスは早く。

Outro:

uMap in da house、flip して立てる、
現場で試して学ぶセットアップ、軽くて熱い運用を続けよう、
Caddy で統一、niroku と並走、シンプルに、力強く。
