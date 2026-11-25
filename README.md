# shopify-test

Shopify アプリの通信内容を確認するための、開発参考用 Rails アプリです。
[shopify_app](https://github.com/Shopify/shopify_app) gem（埋め込みアプリ + トークン交換方式）をベースに、Shopify とのやり取りをすべて DB に記録して閲覧できるようにしています。

## 記録される通信

| 方向 | 種別 | 内容 |
| --- | --- | --- |
| ← inbound | page | 管理画面 iframe からのアクセス（`id_token`, `host`, `shop` などのクエリ） |
| ← inbound | api | App Bridge 経由の `fetch`（`Authorization: Bearer <セッショントークン>`） |
| ← inbound | webhook | Webhook（`X-Shopify-Topic`, `X-Shopify-Hmac-Sha256` などのヘッダーと本文） |
| → outbound | auth | トークン交換（`/admin/oauth/access_token`） |
| → outbound | admin_api | Admin GraphQL API 呼び出し、Webhook 登録など |

- 受信: `lib/shopify_traffic/inbound_logger.rb`（Rack ミドルウェア）
- 送信: `lib/shopify_traffic/outbound_logger.rb`（`ShopifyAPI::Clients::HttpClient#request` に prepend）
- アクセストークン・`client_secret` はマスクして保存します。JWT（`id_token` / セッショントークン）は詳細画面でペイロードをデコード表示します。
- ログビューア: http://localhost:3000/logs （ローカルからのみ。さらに Basic 認証: ユーザー名は任意、パスワードは `.env` の `LOGS_TOKEN`）

## セットアップ

### 1. 公開 URL を用意する

Shopify から到達できる HTTPS の URL が必要です。

**A. 固定ドメイン + `ssh -R`（おすすめ）**

自分で管理するドメインとサーバーがある場合、サーバーのリバースプロキシで TLS を終端し、`ssh -R` で手元の Rails まで転送します。URL が変わらないので、Shopify 側の設定は一度で済みます。

```
Shopify -> https://dev.example.com (リバースプロキシ: TLS 終端)
        -> 中継サーバーの 127.0.0.1:<PORT> (ssh -R)
        -> 手元 PC の 127.0.0.1:3000 (Rails)
```

```sh
ssh -N -R <PORT>:127.0.0.1:3000 \
    -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 relay-host
```

`~/.ssh/config` に書く場合（通常のログイン用とは別の Host にしておくと、ログインのたびにポートを取りに行かずに済みます）:

```sshconfig
Host relay-fwd
  HostName relay-host
  RemoteForward <PORT> 127.0.0.1:3000
  ExitOnForwardFailure yes
  ServerAliveInterval 30
  ServerAliveCountMax 3
  SessionType none
```

`ssh relay-fwd`（自動で再接続したい場合は `autossh -M 0 relay-fwd`）で接続します。

- 中継サーバー側では転送ポートを `127.0.0.1` だけで待ち受け（`GatewayPorts no`）、外からはリバースプロキシ経由でしか届かないようにする
- リバースプロキシは必ず `X-Forwarded-For` を付ける。付けないと Rails からはすべて `127.0.0.1` からのアクセスに見え、`/logs` がインターネットに公開されてしまう
- 外部ネットワークから `https://dev.example.com/logs` を開いて 403 になることを確認する
- 中継サーバー上から `127.0.0.1:<PORT>` に直接送られたリクエストは Rails からローカルと区別できない。そのため `/logs` には `LOGS_TOKEN` の Basic 認証を掛け、web-console（エラー画面の Ruby コンソール）は入れていない
- development モードの Rails がそのまま公開されるので、使わないときは接続を切っておく

**B. Cloudflare Quick Tunnel（手軽だが URL が変わる）**

```sh
cloudflared tunnel --url http://localhost:3000
# => https://xxxx.trycloudflare.com
```

アカウント不要ですぐ使えますが、起動するたびに URL が変わります。長時間の中断（PC のスリープなど）でトンネルが消えることもあります（`Tunnel not found`）。

### 2. Shopify 側でアプリを作る

[Dev Dashboard](https://dev.shopify.com/) でアプリを作成し、Shopify CLI（要 Node.js）で設定を管理します。

```sh
npm install -g @shopify/cli@latest
shopify app config link     # shopify.app.<名前>.toml が作られる
# toml の application_url / redirect_urls / scopes を編集して
shopify app deploy
```

| 項目 | 値 |
| --- | --- |
| `application_url` | `https://<公開URL>`（パスなし） |
| `embedded` | `true` |
| `[access_scopes] scopes` | 必要なスコープ（`.env` の `SCOPES` と揃える） |
| `use_legacy_install_flow` | `false`（Shopify 管理のインストール + トークン交換） |
| `[auth] redirect_urls` | `https://<公開URL>/auth/shopify/callback` |

Dev Dashboard の画面で同じ値を入力してバージョンをリリースしても構いませんが、必須（コンプライアンス）Webhook は toml + CLI でしか設定できません。

### 3. 環境変数

```sh
cp .env.example .env
# SHOPIFY_API_KEY (Client ID), SHOPIFY_API_SECRET (Client secret), HOST (公開URL) を設定
```

### 4. 起動

```sh
bin/rails db:prepare
bin/rails s
```

開発ストアにアプリをインストールし、管理画面からアプリを開くとトップページが表示されます。
トップページから Admin GraphQL API を実行でき、商品を作成/更新/削除すると `products/*` Webhook が届きます。

### 公開 URL を変えたとき

Webhook の購読は 2 系統あり、更新方法が違います。

| 系統 | 登録元 | URL 変更時 |
| --- | --- | --- |
| アプリ全体 | toml の `[[webhooks.subscriptions]]` | toml を直して `shopify app deploy`（相対パスの `uri` は `application_url` に追従） |
| ストアごと | `config.webhooks` を gem がトークン交換時に Admin API で登録 | 自動では変わらない。トークン交換をやり直させる（`Shop` を削除してアプリを開き直す） |

1. `.env` の `HOST` を変えて **Rails を再起動**（`HOST` は起動時に読まれる。古いままだと古い URL で Webhook が登録される）
2. toml の `application_url` / `redirect_urls` を変えて `shopify app deploy`
3. ストアごとの Webhook を登録し直す: `bin/rails runner 'Shop.delete_all'` → 管理画面からアプリを開く

`/logs` の `webhookSubscriptionCreate` / `Update` の `callbackUrl` で、登録された URL を確認できます。

## アプリ専用トークンの発行（client_assertion）

秘密鍵で署名した JWT（`client_assertion` / private_key_jwt）を使い、client credentials grant でアプリ専用トークンを発行します。

### 1. 鍵ペアを作る

Shopify が受け付けるのは RS256（RSA 2048bit 以上）か ES256（EC P-256）のみです。

```sh
bin/rails shopify:keys:generate              # RS256 (RSA 2048bit)
bin/rails shopify:keys:generate ALG=ES256    # ES256 (EC P-256)
```

| オプション | 説明 |
| --- | --- |
| `ALG` | `RS256`（既定）/ `ES256` |
| `RSA_BITS` | RSA の鍵長（既定 2048。2048 未満はエラー） |
| `KEY_DIR` | 出力先（既定 `config/keys`） |
| `FORCE=1` | 既存の鍵を上書きする（指定しないと既存の鍵がある場合は中止） |

`config/keys/`（git 管理外）に以下が出力されます。

| ファイル | 内容 |
| --- | --- |
| `shopify_private_key.pem` | 秘密鍵（パーミッション 600）。JWT の署名に使う。共有しないこと |
| `shopify_public_key.pem` | 公開鍵（PEM） |
| `shopify_public_jwk.json` | 公開鍵（JWK）。**Shopify に登録するのはこちら** |

`kid` は公開鍵の JWK Thumbprint（RFC 7638）で、鍵から一意に決まります（鍵を作り直すと変わる）。
JWT ヘッダーの `kid` と登録した JWK の `kid` が一致している必要があります。

### 2. 公開鍵（JWK）を Shopify に登録する

Dev Dashboard のアプリ設定で、`config/keys/shopify_public_jwk.json` の中身を登録します。
JWKS（鍵のセット）形式を求められた場合は `{"keys": [ ... ]}` で包んでください。

鍵を作り直した場合は、新しい JWK を登録し直す必要があります。

### 3. アプリをストアにインストールしておく

アプリ専用トークンはインストール済みのストアに対してのみ発行されます。

### 4. トークンを発行する

```sh
bin/rails shopify:token:issue SHOP=xxx.myshopify.com
bin/rails shopify:token:issue SHOP=xxx.myshopify.com SHOW_TOKEN=1   # トークンを伏せずに表示
```

`SHOP` はストアの恒久ドメイン（`xxx.myshopify.com`）です。送信した JWT の header / payload と、発行されたトークン・スコープ・有効期限が表示されます。
通信内容は `/logs` の `→ out auth POST .../admin/oauth/access_token` で確認でき、`client_assertion` の JWT もデコード表示されます。

- トークンは `shpua_` で始まり、有効期限は 24 時間（リフレッシュトークンなし。期限が切れたら再発行する）
- 付与されるスコープはアプリ（Dev Dashboard / toml）に設定したスコープ。Rails 側の `SCOPES` ではない

### うまくいかないとき

| レスポンス | 原因 |
| --- | --- |
| 401 `invalid_client` / `Invalid client assertion` | JWK が未登録、または登録した鍵・`kid` が手元の鍵と一致していない |
| 400 `app_not_installed` | アプリがそのストアにインストールされていない |

### コードから使う場合

```ruby
key = OpenSSL::PKey.read(File.read("config/keys/shopify_private_key.pem"))
kid = JSON.parse(File.read("config/keys/shopify_public_jwk.json"))["kid"]
assertion = ShopifyAPI::Auth::ClientAssertion.create(shop: "xxx.myshopify.com", kid:, private_key: key)
session = ShopifyAPI::Auth::ClientCredentials.client_credentials(shop: "xxx.myshopify.com", client_assertion: assertion)
session.access_token
```

## オフライントークンを有期限にする

インストール時のトークン交換で得るオフライントークンは、既定では無期限です（`expiring: 0` を要求）。
`.env` に `SHOPIFY_EXPIRING_OFFLINE_TOKENS=1` を設定すると、トークン交換で有期限トークン + リフレッシュトークンを要求します。
期限切れのセッションは、設定に関係なくトークン交換し直します（そのときは上記の設定に従った種類のトークンになる）。

保存済みの無期限トークンは、アプリのトップページの「オフライントークン」欄にある **有期限トークンに移行** ボタンで移行できます（`POST /api/token/migrate_to_expiring`）。**元に戻す API は無い**ので、確認のチェックを入れたときだけボタンが押せるようにしています。移行ボタンはインストール時の要求の設定とは独立して使えます。

移行の通信は `/logs` の `→ out auth POST .../admin/oauth/access_token` で確認できます（`refresh_token` はマスクして保存）。
`Shop#with_shopify_session` を通して API を呼ぶと、期限切れのアクセストークンはリフレッシュトークンで自動更新されます。

## メモ

- 生成された Webhook ジョブは古いシグネチャ (`handle(topic:, shop:, ...)`) だったため、shopify_api v16 の `handle(data:)` に合わせて修正済み。
- shopify_api 16.4 は `OpenStruct` を require していないため、Gemfile に `ostruct` を追加している。
- 生成テンプレートの App Bridge v2 はトークン交換方式で動かないため、レイアウトを App Bridge v4（CDN）に置き換えている。
