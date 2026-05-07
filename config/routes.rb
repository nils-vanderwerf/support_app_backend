Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  namespace :api do
    get 'csrf_token', to: 'application#csrf_token'
    # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
    # Can be used by load balancers and uptime monitors to verify that the app is live.
    # mount_devise_token_auth_for 'User', at: 'auth'
    get "up" => "rails/health#show", as: :rails_health_check
    get 'user', to: 'sessions#logged_in_user'
    post 'login', to: 'sessions#create'
    delete 'logout', to: 'sessions#destroy'

    # Defines the root path route ("/")
    # root "posts#index"
    resources :users, only: [:create]
    resources :clients
    resources :appointments do
      collection do
        get :pending
        get :recently_accepted
      end
      member do
        patch :approve
        patch :decline
      end
    end
    get 'notifications', to: 'notifications#index'
    resources :conversations, only: [:index, :show, :create] do
      resources :messages, only: [:index, :create]
      member do
        post :ai_respond
        get :suggest_booking
      end
    end
    resources :visit_reports
    post 'ai_booking/chat', to: 'ai_booking#chat'
    post 'chat_simulation', to: 'chat_simulation#simulate'
    get 'dashboard', to: 'dashboard#show'
    resources :support_workers
    post 'vetting/chat', to: 'vetting#chat'
    get  'vetting/status', to: 'vetting#status'
    get  'admin_messages', to: 'admin_messages#index'
    post 'admin_messages', to: 'admin_messages#create'
    post 'password_resets/request', to: 'password_resets#create'
    post 'password_resets/reset', to: 'password_resets#reset'
    namespace :admin do
      get 'applications', to: '/api/admin#applications'
      patch 'applications/:id/approve', to: '/api/admin#approve', as: :approve_application
      patch 'applications/:id/reject', to: '/api/admin#reject', as: :reject_application
      get 'appointments', to: '/api/admin#appointments'
      get 'workers', to: '/api/admin#workers'
      get 'stats', to: '/api/admin#stats'
      get  'messages', to: '/api/admin#messages'
      post 'messages/:support_worker_id/reply', to: '/api/admin#reply_message', as: :reply_message
    end
  end
end
