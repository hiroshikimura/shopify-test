# frozen_string_literal: true

# 保存済みの無期限オフライントークンを、有期限トークン + リフレッシュトークンに移行する（元に戻す API は無い）。
# インストール時の要求 (SHOPIFY_EXPIRING_OFFLINE_TOKENS) とは独立。移行後にトークン交換し直すと、その設定に従った種類になる
class Api::TokensController < AuthenticatedController
  rescue_from ShopifyAPI::Errors::HttpResponseError do |e|
    render(json: { error: "移行に失敗しました (HTTP #{e.code}): #{e.message}" }, status: :bad_gateway)
  end

  def migrate_to_expiring
    shop = Shop.find_by!(shopify_domain: current_shopify_session.shop)
    # 検証用: force=1 なら有期限トークンでもそのまま Shopify に送り、応答を確かめられるようにする
    if shop.expires_at.present? && !ActiveModel::Type::Boolean.new.cast(params[:force])
      return render(json: { error: "既に有期限トークンです" }, status: :unprocessable_entity)
    end

    session = ShopifyAPI::Auth::TokenExchange.migrate_to_expiring_token(
      shop: shop.shopify_domain,
      non_expiring_offline_token: shop.shopify_token
    )
    Shop.store(session)
    shop.reload

    render(json: { expires_at: shop.expires_at, refresh_token_expires_at: shop.refresh_token_expires_at })
  end
end
