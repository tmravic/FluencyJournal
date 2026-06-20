Rails.application.routes.draw do
  resources :followup_template_prompts, only: [:index] do
    collection do
      delete :destroy_selected
      get    :cancel
    end
  end
  resources :journals do
    collection do
      get :all
    end
    member do
      get :open_ai_assistant
      get :reading_mode
      get :speak
      post :mark_journal_as_studied
      get :change_due_date
      post :update_due_date
    end
    resources :entries do
      member do
        get :speak
      end
    end
    resources :quizzes, only: [:show] do
      collection do
        get :prepare_quiz
        get :reset_quiz
        get :close_quiz
        get :peek
        get :unpeek
      end
      member do
        get :grade_quiz
      end
      resources :quiz_answers, except: [:index, :destroy, :update] do
        member do
          get :retry
        end
      end
    end
    resources :ai_queries, only: [ :show, :destroy ] do
      collection do
        post :ai_request
      end
    end
  end
  resources :notes do
    collection do
      get :all
      get :drafts
      get :for_journal
      get :new_automatic, as: :new_automatic
    end
    member do
      post :mark_note_as_studied
      get :change_due_date
      post :update_due_date
      get :link_journals
      post :update_journals
      get :cancel_link_journals
    end
  end
  resources :followups, only: [ :new, :create, :show, :destroy ]
  resources :ai_outputs, only: [ :destroy ] do
    member do
      get :speak
    end
  end

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
