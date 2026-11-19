# Shopify との通信を CommunicationLog に記録する（ログは /logs で確認）
require Rails.root.join("lib/shopify_traffic/outbound_logger").to_s

ShopifyAPI::Clients::HttpClient.prepend(ShopifyTraffic::OutboundLogger)
