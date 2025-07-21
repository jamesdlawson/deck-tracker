class SessionState
  attr_accessor :decks, :drawn_cards

  def initialize
    @decks = []
    @drawn_cards = {} # To hold recently drawn cards for display
  end

  def add_deck(deck_name)
    return unless @decks.length < 10
    deck_data = DeckLoader.find(deck_name)
    return unless deck_data

    # Generate a unique ID for each card as it's loaded
    new_cards = deck_data['deck']['cards'].map do |card_data|
      Card.new(
        id: SecureRandom.uuid,
        name: card_data['name'],
        data: card_data['data'] || {}
      )
    end

    new_deck = Deck.new(
      id: Time.now.to_f.to_s, # Simple unique ID for the session deck instance
      name: deck_data['deck']['name'],
      cards: new_cards
    )
    new_deck.shuffle!
    decks << new_deck
  end

  def find_deck(deck_id)
    decks.find { |deck| deck.id == deck_id }
  end

  def remove_deck(deck_id)
    decks.reject! { |deck| deck.id == deck_id }
  end
end
