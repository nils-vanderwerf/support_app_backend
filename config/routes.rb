Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  namespace :api do
    get 'csrf_token', to: 'application#csrf_token'
    # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
    # Can be used by load balancers and uptime monitors to verify that the app is live.
    # mount_devise_token_auth_for 'User', at: 'auth'
    get "up" => "rails/health#show", as: :rails_health_check

    # Defines the root path route ("/")
    # root "posts#index"
    resources :users, only: [:create]
    resources :clients
    resources :appointments
    resources :visit_reports
    resources :support_workers
  end
end
