# products/* の Webhook を受け取るだけのジョブ（中身は /logs で確認できる）
class ProductsJob < ActiveJob::Base
  extend ShopifyAPI::Webhooks::WebhookHandler

  def self.handle(data:)
    perform_later(topic: data.topic, shop_domain: data.shop, webhook: data.body)
  end

  def perform(topic:, shop_domain:, webhook:)
    logger.info("#{self.class} received #{topic} from #{shop_domain}: product id=#{webhook['id']} title=#{webhook['title']}")
  end
end
