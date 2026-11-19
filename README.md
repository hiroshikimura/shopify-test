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
- ログビューア: http://localhost:3000/logs （トンネル経由では 403。ローカルからのみ）

## セットアップ

### 1. トンネルを用意する

Shopify から到達できる HTTPS の URL が必要です。例（Cloudflare Tunnel）:

```sh
cloudflared tunnel --url http://localhost:3000
# => https://xxxx.trycloudflare.com
```

ngrok でも可（`ngrok http 3000`）。URL が変わったら下記の設定もすべて更新してください。

### 2. Shopify 側でアプリを作る

[Dev Dashboard](https://dev.shopify.com/) でアプリを作成し、バージョンに以下を設定してリリースします（`shopify.app.toml` と同じ内容）。

- App URL: `https://xxxx.trycloudflare.com`
- 埋め込み: 有効
- スコープ: `read_products`
- リダイレクト URL: `https://xxxx.trycloudflare.com/auth/shopify/callback`
- 「レガシーインストールフローを使用」: 無効（Shopify 管理のインストール + トークン交換）

Shopify CLI（要 Node.js）を使う場合は `shopify.app.toml` を編集して `shopify app deploy` でも同じことができます。

### 3. 環境変数

```sh
cp .env.example .env
# SHOPIFY_API_KEY (Client ID), SHOPIFY_API_SECRET (Client secret), HOST (トンネルURL) を設定
```

### 4. 起動

```sh
bin/rails db:prepare
bin/rails s
```

開発ストアにアプリをインストールし、管理画面からアプリを開くとトップページが表示されます。
トップページから Admin GraphQL API を実行でき、商品を作成/更新/削除すると `products/*` Webhook が届きます。

## メモ

- 生成された Webhook ジョブは古いシグネチャ (`handle(topic:, shop:, ...)`) だったため、shopify_api v16 の `handle(data:)` に合わせて修正済み。
- shopify_api 16.4 は `OpenStruct` を require していないため、Gemfile に `ostruct` を追加している。
- 生成テンプレートの App Bridge v2 はトークン交換方式で動かないため、レイアウトを App Bridge v4（CDN）に置き換えている。
