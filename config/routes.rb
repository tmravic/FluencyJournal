Rails.application.routes.draw do
  resources :commits
  resources :entries
  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  root "pages#home"
  get "/journal", to: "pages#journal"
  post "ai_request", to: "entries#ai_request"

  get "/up/", to: "up#index", as: :up
  get "/up/databases", to: "up#databases", as: :up_databases
  mount ActionCable.server, at: '/cable'
  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
