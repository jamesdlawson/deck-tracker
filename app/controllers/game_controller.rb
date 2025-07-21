class GameController < ApplicationController
  def show
    redirect_to root_path, alert: 'No active session.' and return unless @session_id
    @available_decks = DeckLoader.all_deck_names
    # Renders app/views/game/show.html.erb automatically.
  end
end
