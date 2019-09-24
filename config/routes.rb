Rails.application.routes.draw do
  root to: 'root#index'

  match "/401", :to => "errors#unauthorized", :via => :all
  match "/404", :to => "errors#not_found", :via => :all, constraints: lambda { |req| req.format == :html }
  match "/500", :to => "errors#internal_server_error", :via => :all
  match "/503", :to => "errors#internal_server_error", :via => :all

  get '/contact_us', to: 'pages#contact_us'
  post '/contact_us', to: 'pages#create_contact_us'
  get '/help', to: 'pages#help'
  get '/help_step0', to: 'pages#help_step0'
  get '/help_step1', to: 'pages#help_step1'
  get '/help_step2', to: 'pages#help_step2'
  get '/help_step3', to: 'pages#help_step3'
  get '/help_step4', to: 'pages#help_step4'
  get '/help_step5', to: 'pages#help_step5'
  get '/help_step6', to: 'pages#help_step6'
  get '/update_case_information', to: 'pages#update_case_information'
  get '/updating_ndelius', to: 'pages#updating_ndelius'
  get '/missing_cases', to: 'pages#missing_cases'
  get '/repatriated', to: 'pages#repatriated'
  get '/scottish_northern_irish', to: 'pages#scottish_northern_irish'
  get '/contact', to: 'pages#contact'

  get '/auth/:provider/callback', to: 'sessions#create'
  get '/signout', to: 'sessions#destroy'

  resources :prisons do
    resources :prisons, only: :index
    resources :dashboard, only: :index
    resources :caseload, only: %i[ index new ]
    get('/prisoners/:id' => 'prisoners#show', as: 'prisoner_show')
    get('/prisoners/:id/image.jpg' => 'prisoners#image', as: 'prisoner_image')
    resources :allocations, only: %i[ show new create edit update ], param: :nomis_offender_id, path_names: {
        new: ':nomis_offender_id/new',
    }
    get('/allocations/:nomis_offender_id/history' => 'allocations#history', as: 'allocation_history')
    get('/allocations/confirm/:nomis_offender_id/:nomis_staff_id' => 'allocations#confirm', as: 'confirm_allocation')
    get('/reallocations/confirm/:nomis_offender_id/:nomis_staff_id' => 'allocations#confirm_reallocation', as: 'confirm_reallocation')
    resources :case_information, only: %i[new create edit update show], param: :nomis_offender_id, controller: 'case_information', path_names: {
        new: 'new/:nomis_offender_id',
    }
    resources :coworking, only: [:new, :create, :destroy], param: :nomis_offender_id, path_names: {
        new: ':nomis_offender_id/new',
    } do
      get('confirm_coworking_removal' => 'coworking#confirm_removal', as: 'confirm_removal')
    end
    get('/coworking/confirm/:nomis_offender_id/:primary_pom_id/:secondary_pom_id' => 'coworking#confirm', as: 'confirm_coworking_allocation')

    resource :overrides,  only: %i[ new create ], path_names: { new: 'new/:nomis_offender_id/:nomis_staff_id'}
    resources :poms, only: %i[ index show edit update ], param: :nomis_staff_id

    get('/debugging' => 'debugging#debugging')
    get('/search' => 'search#search')

    get('/summary' => 'summary#index')
    get('/summary/allocated' => 'summary#allocated')
    get('/summary/unallocated' => 'summary#unallocated')
    get('/summary/pending' => 'summary#pending')
  end

  resources :health, only: %i[ index ], controller: 'health'
  resources :status, only: %i[ index ], controller: 'status'

  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'
  mount Flipflop::Engine => "/flip-flop-admin"
end
