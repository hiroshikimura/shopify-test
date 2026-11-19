Rails.application.routes.draw do
  root to: "home#index"

  namespace :api do
    post "graphql", to: "graphql#create"
    get "logs", to: "logs#index"
  end

  resources :logs, only: %i[index show] do
    delete :destroy_all, on: :collection
  end

  # /login, /auth/shopify/callback, /webhooks/:type, /patch_shopify_id_token など
  mount ShopifyApp::Engine, at: "/"

  get "up" => "rails/health#show", as: :rails_health_check
end
