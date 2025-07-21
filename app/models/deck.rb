class Deck
  attr_accessor :id, :name, :cards, :discard_pile
  attr_reader :discard_visibility

  def initialize(id:, name:, cards: [], discard_visibility: :visible)
    @id = id
    @name = name
    @cards = cards
    @discard_pile = []
    @discard_visibility = discard_visibility
  end

  def find_card(card_id:)
    cards.find { |c| c.id == card_id }
  end

  def shuffle!
    cards.shuffle!
  end

  def shuffle_in_discard!
    cards.append(discard_pile)
    discard_pile = []
    shuffle!
  end

  def draw!(n: 1)
    drawn_cards = cards.pop(n)
    discard_pile.push(drawn_cards)
  end
  alias :select_random!, :draw!

  def select!(id:)
    cards.index {|card| card.id == id}&.then do |index|
      cards.delete_at(index)
    end
  end

  # Array of cards or single card
  def add_cards_to_top!(new_cards:)
    cards.append(new_cards).flatten!
  end

  # Array of cards or single card
  def add_cards_to_bottom!(new_cards:)
    cards.prepend(new_cards).flatten!
  end

  # It's up to the caller to clean up the other deck
  def merge!(other_deck)
    cards.append(other_deck.cards)
    discard_pile.append(other_deck.discard_pile)
  end
end
