Rails.application.routes.draw do
  resources :journals do
    member do
      get :open_ai_assistant
    end
    resources :entries
    resources :ai_queries, only: [ :show, :destroy ] do
      collection do
        post :ai_request
      end
    end
  end
  resources :notes do
    collection do
      get :all
      get :new_automatic, as: :new_automatic
    end
    member do
      post :mark_note_as_studied
    end
  end
  resources :followups, only: [ :new, :create, :show, :destroy ]
  resources :ai_outputs, only: [ :destroy ]

  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  root "pages#home"

  get "/up", to: "up#index", as: :up
  get "/up/databases", to: "up#databases", as: :up_databases
  mount ActionCable.server, at: "/cable"
  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
