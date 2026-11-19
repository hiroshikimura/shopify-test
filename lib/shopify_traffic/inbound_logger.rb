module ShopifyTraffic
  # Shopify (管理画面の iframe / Webhook / App Bridge 経由の fetch) からアプリへのリクエストを記録する Rack ミドルウェア
  class InboundLogger
    IGNORE_PATHS = %r{\A/(assets|logs|api/logs|up|favicon|icon|rails/|cable)}

    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      return @app.call(env) if request.path.match?(IGNORE_PATHS)

      body = request.raw_post.to_s
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      status, headers, response = @app.call(env)
      category = category_for(request)
      response_body, response = read_body(response) if %w[api webhook].include?(category)

      CommunicationLog.record(
        direction: "inbound",
        category: category,
        http_method: request.request_method,
        url: request.fullpath,
        shop_domain: request.headers["X-Shopify-Shop-Domain"] || request.GET["shop"],
        request_headers: request_headers(env),
        request_body: body.presence,
        status: status,
        response_headers: headers.to_h,
        response_body: response_body,
        duration_ms: elapsed_ms(started)
      )
      [ status, headers, response ]
    rescue => e
      CommunicationLog.record(
        direction: "inbound",
        category: category_for(request),
        http_method: request.request_method,
        url: request.fullpath,
        request_headers: request_headers(env),
        request_body: body.presence,
        error: "#{e.class}: #{e.message}",
        duration_ms: started && elapsed_ms(started)
      )
      raise
    end

    private

    def category_for(request)
      case request.path
      when %r{\A/webhooks} then "webhook"
      when %r{\A/api/} then "api"
      when %r{\A/(login|auth|patch_shopify_id_token|logout)} then "auth"
      else "page"
      end
    end

    # JSON などのレスポンス本文も残したいので読み切ってから返し直す
    def read_body(response)
      parts = []
      response.each { |part| parts << part }
      response.close if response.respond_to?(:close)
      [ parts.join, parts ]
    end

    def request_headers(env)
      env.each_with_object({}) do |(key, value), headers|
        next unless key.start_with?("HTTP_") || %w[CONTENT_TYPE CONTENT_LENGTH].include?(key)

        name = key.delete_prefix("HTTP_").split("_").map(&:capitalize).join("-")
        headers[name] = value
      end
    end

    def elapsed_ms(started)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    end
  end
end
