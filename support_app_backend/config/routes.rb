Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  namespace :api do
    # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
    # Can be used by load balancers and uptime monitors to verify that the app is live.
    devise_for :users, skip: :all # Skip all to avoid conflicts, then manually add what you need

    post 'users', to: 'registrations#create', as: :user_registration

    devise_scope :user do
      post 'users/sign_in', to: 'devise/sessions#create', as: :user_session
      delete 'users/sign_out', to: 'devise/sessions#destroy', as: :destroy_user_session
    end

    mount_devise_token_auth_for 'User', at: 'auth', skip: [:omniauth_callbacks], as: :api_auth

    get "up" => "rails/health#show", as: :rails_health_check
    get 'auth', to: 'users#show'

    # Defines the root path route ("/")
    # root "posts#index"
    resources :clients
    resources :appointments
    resources :visit_reports
    resources :support_workers
  end
end
