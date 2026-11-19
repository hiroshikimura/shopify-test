# frozen_string_literal: true

# 画面から任意の GraphQL を Admin API に投げる（App Bridge のセッショントークンで認証）
class Api::GraphqlController < AuthenticatedController
  def create
    client = ShopifyAPI::Clients::Graphql::Admin.new(session: current_shopify_session)
    response = client.query(query: params.require(:query), variables: params[:variables].presence&.to_unsafe_h)
    render(json: { status: response.code, body: response.body })
  rescue ShopifyAPI::Errors::HttpResponseError => e
    render(json: { status: e.code, error: e.message, body: e.response.body }, status: :bad_gateway)
  end
end
