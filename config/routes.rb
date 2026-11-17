Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "contracts#index"
  resource :session, only: [ :new, :create, :destroy ]
  resource :contract_suggestion, only: [ :new, :create ] do
    post :apply, on: :collection
  end
  resources :contracts, only: [ :index, :show, :new, :create, :edit, :update ] do
    post :decision, on: :member
  end

  namespace :api do
    namespace :v1, defaults: { format: :json } do
      resources :contracts, only: [ :index, :show, :create, :update ] do
        post :decision, on: :member
      end
    end
  end
end
