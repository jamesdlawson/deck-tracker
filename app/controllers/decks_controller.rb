class DecksController < ApplicationController
  def add_deck
    @session_state.add_deck(params[:deck_name])
    render partial: 'game/session_decks', locals: { session_state: @session_state }
  end

  def remove_deck
    @session_state.remove_deck(params[:deck_id])
    render partial: 'game/session_decks', locals: { session_state: @session_state }
  end

  def shuffle
    deck = @session_state.find_deck(params[:deck_id])
    deck&.shuffle!
    render partial: 'game/deck', locals: { deck: deck }
  end

  def shuffle_with_discard
    deck = @session_state.find_deck(params[:deck_id])
    deck&.shuffle_discard_into_deck!
    render partial: 'game/deck', locals: { deck: deck }
  end

  def draw
    deck = @session_state.find_deck(params[:deck_id])
    count = params[:count].to_i
    drawn = deck&.draw(count)
    @session_state.drawn_cards[deck.id] = drawn if deck
    render partial: 'game/session_decks', locals: { session_state: @session_state }
  end

  def move_random
    source_deck = @session_state.find_deck(params[:source_deck_id])
    target_deck = @session_state.find_deck(params[:target_deck_id])
    if source_deck && target_deck
      card_to_move = source_deck.cards.sample
      if card_to_move
        source_deck.cards.delete(card_to_move)
        target_deck.cards.prepend(card_to_move)
      end
    end
    render partial: 'game/session_decks', locals: { session_state: @session_state }
  end

  def move_specific
    source_deck = @session_state.find_deck(params[:source_deck_id])
    target_deck = @session_state.find_deck(params[:target_deck_id])
    if source_deck && target_deck
      card_to_move = source_deck.find_card(params[:card_id])
      if card_to_move
        source_deck.cards.delete(card_to_move)
        target_deck.cards.prepend(card_to_move)
      end
    end
    render partial: 'game/session_decks', locals: { session_state: @session_state }
  end

  def merge
    deck_one = @session_state.find_deck(params[:deck_id_one])
    deck_two = @session_state.find_deck(params[:deck_id_two])
    if deck_one && deck_two && deck_one != deck_two
      deck_one.merge!(deck_two)
      @session_state.remove_deck(deck_two.id)
    end
    render partial: 'game/session_decks', locals: { session_state: @session_state }
  end
end
