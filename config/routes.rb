Rails.application.routes.draw do
  resources :journals do
    member do
      get :open_ai_assistant
    end
    resources :entries
    resources :ai_query, only: [:show, :destroy] # look up how to shorten this route
  end
  resources :notes do
    collection do
      get :all
    end
    member do
      post :mark_note_as_studied
    end
  end
  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  root "pages#home"
  post "ai_request", to: "journals#ai_request"

  get "/up/", to: "up#index", as: :up
  get "/up/databases", to: "up#databases", as: :up_databases
  mount ActionCable.server, at: '/cable'
  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
