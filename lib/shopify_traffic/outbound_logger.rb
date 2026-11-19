module ShopifyTraffic
  # アプリから Shopify への HTTP リクエスト (Admin API / トークン交換 / Webhook 登録など) を記録する。
  # shopify_api gem の通信はすべて ShopifyAPI::Clients::HttpClient#request を通るので、そこに prepend する。
  module OutboundLogger
    def request(request, response_as_struct: false)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = super
      record_outbound(request, started, response:)
      response
    rescue ShopifyAPI::Errors::HttpResponseError => e
      record_outbound(request, started, response: e.response, error: "#{e.class}: #{e.message}")
      raise
    rescue => e
      record_outbound(request, started, error: "#{e.class}: #{e.message}")
      raise
    end

    private

    def record_outbound(request, started, response: nil, error: nil)
      url = URI(request_url(request))
      url.query = URI.encode_www_form(request.query) if request.query.present?
      headers = @headers.dup
      headers["Content-Type"] = request.body_type if request.body_type
      headers = headers.merge(request.extra_headers) if request.extra_headers

      CommunicationLog.record(
        direction: "outbound",
        category: url.path.start_with?("/admin/oauth") ? "auth" : "admin_api",
        http_method: request.http_method.to_s.upcase,
        url: url.to_s,
        shop_domain: url.host,
        request_headers: headers,
        request_body: request.body,
        status: response&.code,
        response_headers: response&.headers,
        response_body: response&.body,
        duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round,
        error: error
      )
    end
  end
end
