Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "contracts#index"
  resource :session, only: [ :new, :create, :destroy ]
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
