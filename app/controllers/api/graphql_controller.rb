# frozen_string_literal: true

# 画面から任意の GraphQL を Admin API に投げる（App Bridge のセッショントークンで認証）
class Api::GraphqlController < AuthenticatedController
  # アクション内で rescue すると、401 時にトークン交換して再試行する shopify_app の
  # with_token_refetch (around_action) にエラーが届かない。rescue_from は around_action の外側で効く
  rescue_from ShopifyAPI::Errors::HttpResponseError do |e|
    render(json: { status: e.code, error: e.message, body: e.response.body }, status: :bad_gateway)
  end

  def create
    client = ShopifyAPI::Clients::Graphql::Admin.new(session: current_shopify_session)
    response = client.query(query: params.require(:query), variables: params[:variables].presence&.to_unsafe_h)
    render(json: { status: response.code, body: response.body })
  end
end
