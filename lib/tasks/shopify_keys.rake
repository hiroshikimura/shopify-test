# Shopify の client credentials grant で client_assertion (private_key_jwt) に使う鍵ペアを生成する。
# shopify_api の ShopifyAPI::Auth::ClientAssertion が受け付けるのは RSA 2048bit 以上 (RS256) か EC P-256 (ES256) のみ。
#
#   bin/rails shopify:keys:generate                 # RS256 (RSA 2048bit)
#   bin/rails shopify:keys:generate ALG=ES256       # ES256 (EC P-256)
#   bin/rails shopify:keys:generate RSA_BITS=4096   # RSA の鍵長を変える
#   bin/rails shopify:keys:generate KEY_DIR=tmp/keys FORCE=1
namespace :shopify do
  namespace :keys do
    desc "Shopify 連携用の鍵ペア (秘密鍵/公開鍵 PEM と公開鍵 JWK) を生成する"
    task generate: :environment do
      algorithm = ENV.fetch("ALG", ShopifyAPI::Auth::ClientAssertion::RSA_ALGORITHM).upcase
      key_dir = Rails.root.join(ENV.fetch("KEY_DIR", "config/keys"))
      paths = {
        private_pem: key_dir.join("shopify_private_key.pem"),
        public_pem: key_dir.join("shopify_public_key.pem"),
        public_jwk: key_dir.join("shopify_public_jwk.json")
      }

      display = ->(path) { path.to_s.delete_prefix("#{Rails.root}/") }

      existing = paths.values.select(&:exist?)
      if existing.any? && ENV["FORCE"].blank?
        abort "既に鍵があります (上書きするには FORCE=1): #{existing.map(&display).join(', ')}"
      end

      private_key =
        case algorithm
        when ShopifyAPI::Auth::ClientAssertion::RSA_ALGORITHM
          bits = ENV.fetch("RSA_BITS", ShopifyAPI::Auth::ClientAssertion::MIN_RSA_KEY_BITS).to_i
          if bits < ShopifyAPI::Auth::ClientAssertion::MIN_RSA_KEY_BITS
            abort "RSA_BITS は #{ShopifyAPI::Auth::ClientAssertion::MIN_RSA_KEY_BITS} 以上にしてください"
          end
          OpenSSL::PKey::RSA.generate(bits)
        when ShopifyAPI::Auth::ClientAssertion::EC_ALGORITHM
          OpenSSL::PKey::EC.generate("prime256v1")
        else
          abort "ALG は RS256 か ES256 を指定してください (指定値: #{algorithm})"
        end

      # kid は公開鍵の JWK Thumbprint (RFC 7638)。JWT ヘッダーの kid と Shopify に登録する JWK の kid を一致させる
      jwk = JWT::JWK.new(private_key, { alg: algorithm, use: "sig" }, kid_generator: JWT::JWK::Thumbprint)
      public_jwk = jwk.export # include_private を指定しない限り公開鍵の成分のみ

      FileUtils.mkdir_p(key_dir)
      File.write(paths[:private_pem], private_key.private_to_pem)
      File.chmod(0o600, paths[:private_pem])
      File.write(paths[:public_pem], private_key.public_to_pem)
      File.write(paths[:public_jwk], JSON.pretty_generate(public_jwk) + "\n")

      puts "#{algorithm} の鍵ペアを生成しました"
      paths.each_value { |path| puts "  #{display.(path)}" }
      puts
      puts "kid: #{public_jwk[:kid]}"
      puts "公開鍵 (JWK):"
      puts JSON.pretty_generate(public_jwk)
    end
  end
end
