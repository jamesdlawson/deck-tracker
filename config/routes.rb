Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root 'sessions#new'
  resource :session, only: [:new, :create, :destroy]
  resource :game, only: [:show]

  # All actions that modify the state of decks
  scope '/game', controller: 'decks' do
    post 'add_deck'
    delete 'decks/:deck_id', action: :remove_deck, as: :remove_deck
    post 'decks/:deck_id/shuffle', action: :shuffle, as: :shuffle_deck
    post 'decks/:deck_id/shuffle_with_discard', action: :shuffle_with_discard, as: :shuffle_with_discard
    post 'decks/:deck_id/draw', action: :draw, as: :draw_card
    post 'decks/move_random', action: :move_random, as: :move_random_card
    post 'decks/move_specific', action: :move_specific, as: :move_specific_card
    post 'decks/merge', action: :merge, as: :merge_decks
  end
end
