# frozen_string_literal: true

# Admin link（extensions/product-admin-link）から管理画面の iframe 内で開かれるページ
class AdminLinksController < ApplicationController
  include ShopifyApp::EmbeddedApp
  include ShopifyApp::EnsureInstalled

  PRODUCT_QUERY = <<~GRAPHQL
    query($id: ID!) {
      product(id: $id) {
        id
        title
        handle
        status
        vendor
        totalInventory
        updatedAt
      }
    }
  GRAPHQL

  # action 内で rescue すると 401 時のトークン交換（with_token_refetch）が効かなくなるので rescue_from で受ける
  rescue_from ShopifyAPI::Errors::HttpResponseError do |e|
    @error = "Admin API の呼び出しに失敗しました (HTTP #{e.code}): #{e.message}"
    render(:product)
  end

  def product
    @shop_origin = current_shopify_domain
    @received_params = request.query_parameters
    @product_gid = product_gid(params[:id])
    return if @product_gid.nil?

    client = ShopifyAPI::Clients::Graphql::Admin.new(session: current_shopify_session)
    response = client.query(query: PRODUCT_QUERY, variables: { id: @product_gid })
    @product = response.body.dig("data", "product")
    @errors = response.body["errors"]
  end

  private

  # 数値 ID と GID のどちらで渡されても扱えるようにする
  def product_gid(id)
    return if id.blank?

    id.to_s.start_with?("gid://") ? id.to_s : "gid://shopify/Product/#{id}"
  end
end
