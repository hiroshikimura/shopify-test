# Shopify との通信内容を記録する（開発参考用）
class CommunicationLog < ApplicationRecord
  MAX_BODY_SIZE = 200.kilobytes
  # ログに平文で残さないキー（値の先頭だけ残してマスクする）
  SECRET_KEYS = %w[x-shopify-access-token client_secret access_token refresh_token].freeze

  scope :recent, -> { order(id: :desc) }

  class << self
    # 記録に失敗してもアプリ本体の処理は止めない
    def record(**attrs)
      attrs[:request_headers] = mask_hash(attrs[:request_headers])
      attrs[:response_headers] = mask_hash(attrs[:response_headers])
      attrs[:request_body] = prepare_body(attrs[:request_body])
      attrs[:response_body] = prepare_body(attrs[:response_body])
      create!(**attrs)
    rescue => e
      Rails.logger.error("[CommunicationLog] 記録に失敗しました: #{e.class}: #{e.message}")
      nil
    end

    def mask(value)
      str = value.to_s
      str.length > 10 ? "#{str[0, 10]}...(masked)" : "(masked)"
    end

    private

    def mask_hash(hash)
      return if hash.nil?

      hash.to_h.to_h do |key, value|
        [ key.to_s, SECRET_KEYS.include?(key.to_s.downcase) ? mask(value) : value ]
      end
    end

    def prepare_body(body)
      return if body.nil?

      text =
        case body
        when String then mask_json_string(body)
        when Hash, Array then JSON.pretty_generate(mask_secrets(body))
        else body.respond_to?(:to_h) ? JSON.pretty_generate(mask_secrets(body.to_h)) : body.inspect
        end
      text.bytesize > MAX_BODY_SIZE ? "#{text.byteslice(0, MAX_BODY_SIZE).scrub}\n...(truncated)" : text
    end

    def mask_json_string(str)
      return str if str.empty?

      JSON.pretty_generate(mask_secrets(JSON.parse(str)))
    rescue JSON::ParserError
      str.dup.force_encoding(Encoding::UTF_8).scrub
    end

    def mask_secrets(obj)
      case obj
      when Hash then obj.to_h { |k, v| [ k, SECRET_KEYS.include?(k.to_s.downcase) ? mask(v) : mask_secrets(v) ] }
      when Array then obj.map { |v| mask_secrets(v) }
      else obj
      end
    end
  end

  def inbound? = direction == "inbound"

  # クエリの id_token や Authorization ヘッダーのセッショントークン(JWT)を、署名検証せずにデコードして表示用に返す
  def decoded_jwts
    tokens = {}
    query = Rack::Utils.parse_query(URI(url).query.to_s)
    tokens["query: id_token"] = query["id_token"] if query["id_token"].present?
    auth = request_headers&.dig("Authorization").to_s
    tokens["header: Authorization"] = auth.delete_prefix("Bearer ") if auth.start_with?("Bearer ")
    body = JSON.parse(request_body.to_s) rescue {}
    %w[subject_token client_assertion].each do |key|
      tokens["body: #{key}"] = body[key] if body.is_a?(Hash) && body[key].present?
    end

    tokens.filter_map do |label, token|
      _header, payload, = token.split(".")
      next unless payload

      [ label, JSON.pretty_generate(JSON.parse(Base64.urlsafe_decode64(payload + "=" * (-payload.length % 4)))) ]
    rescue ArgumentError, JSON::ParserError
      nil
    end.to_h
  end
end
