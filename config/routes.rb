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
      get :compare
    end
    resources :entries, only: [ :new, :create, :edit, :update, :destroy ] do
      member do
        get :speak
        get :cancel
      end
    end
    resources :quizzes, only: [:show, :destroy] do
      collection do
        post :prepare_quiz
        delete :reset_quiz
        get :close_quiz
      end
      member do
        post :grade_quiz
        get :peek
        get :unpeek
        get :show_original_language
        get :hide_original_language
        get :show_hint
        get :hide_hint
      end
      resources :quiz_answers, only: [ :create, :show, :edit ] do
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
  resources :followups, only: [ :new, :create, :show, :destroy ] do
    collection do
      get :cancel
    end
  end
  resources :ai_outputs, only: [ :destroy ] do
    member do
      get :speak
    end
  end

  resource :session, only: %i[ new create destroy ]
  resources :passwords, param: :token, only: %i[ new create edit update ]
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
