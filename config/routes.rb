# frozen_string_literal: true

Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/api_docs'
  mount Rswag::Api::Engine => '/api_docs'
  namespace :api do
    namespace :v1 do
      scope :auth, controller: :auth do
        post 'login'
        post 'verify_2fa'
        patch 'activate'
        patch 'verify'
        post 'password/reset', to: 'auth#request_reset'
        patch 'password/reset', to: 'auth#confirm_reset'
      end

      post 'stripe_payments_webhook/handle', to: 'stripe_payments_webhook#handle'

      resources :users, only: %i[create index show update destroy] do
        collection do
          get 'me'
          post 'logout'
        end

        member do
          get 'actions'
          patch 'role/update', to: 'users#role'
          patch 'update_location'
          patch 'update_details'
          patch 'update_entrepreneur_details'
        end
      end

      resources :products, only: %i[index create show update destroy] do
        member do
          post 'like'
          post 'rate'
          post 'comment'
          post 'create_photo'
        end
      end

      resources :payments, only: %i[index create show]

      resources :orders, only: %i[index create show update destroy] do
        collection do
          get 'me'
        end
        member do
          post 'cancel'
          post 'products', to: 'orders#add_product'
          delete 'products/:product_id', to: 'orders#remove_product', as: :remove_product
        end
      end

      resource :cart, controller: 'cart', only: [:show] do
        member do
          post 'add/:product_id', to: 'cart#add', as: 'add_to'
          delete 'revoke/:item_id', to: 'cart#revoke', as: 'revoke_from'
          delete 'clear'
        end
      end

      scope :diagnostics, controller: :diagnostics do
        get 'readiness', to: 'diagnostics#readiness'
        get 'health', to: 'diagnostics#health'
        get 'metrics', to: 'diagnostics#metrics'
      end
    end
  end
end
