# Deck Tracker Application: Requirements & Implementation Plan

This document outlines the functional requirements and the implementation plan for the deck tracker application.

---
## Requirements

### General
* **Technology Stack:** The application will be built with Ruby on Rails, using ERB with HTMX for the front end.
* **Data Persistence:** No persistent database will be used. Application state will be managed in-memory using `Rails.cache`. State loss upon server restart is acceptable.
* **Design:** The initial version will be text-based with minimal styling, focusing on usability. Card images and advanced styling are future considerations.
* **Architecture:** The design will favor composition over inheritance.

### Functional Requirements
1.  **Predefined Decks:** Decks of cards can be predefined in JSON files. The JSON structure should use `deck` and `card` keys.
2.  **Card Definition:** Each card must have a `name`. A unique **`id`** (UUID) will be **generated for each card when it is loaded into a session** to guarantee uniqueness.
3.  **Session Management:**
    * A user must specify a custom Session ID upon first connecting.
    * The Session ID will serve as the cache key to manage and reconnect to a game state.
    * A single server instance can track up to 10 decks per session.
4.  **Deck Selection:** Once in a session, a user can select and add decks to their session from the set of predefined decks.
5.  **Session Actions:** The following actions must be available at the session level:
    * Clear Session (resets the session to an empty state).
    * Add Deck to Session.
    * Remove Deck from Session.
    * Terminate Session (clears the cache for that session ID).
6.  **Deck State:**
    * Each deck must have its own tracked discard pile.
    * Each deck's definition can specify the visibility of its discard pile (e.g., hidden, shown, show top 'n' cards).
7.  **Deck Actions:** Each deck must support the following generic actions:
    * Shuffle the discard pile back into the deck.
    * Shuffle the main deck without adding the discard pile.
    * Draw one or more cards.
    * Draw a card randomly from one deck and move it to another deck.
    * Move a user-selected card from one deck to another.
    * Merge two decks together (including their discard piles).

---
## Implementation Plan

This plan outlines the steps to build the application according to the requirements.

### Step 1: Project Setup
1.  **Create Rails App:** Initialize a new Rails application configured to skip Active Record.
    ```bash
    rails new deck_tracker --skip-active-record
    ```
2.  **Configure Cache:** In `config/environments/development.rb`, ensure the cache store is set to `:memory_store`.
3.  **Integrate HTMX:** Include HTMX directly from a CDN. In `app/views/layouts/application.html.erb`, add the script tag in the `<head>` section.
    ```html
    <head>
      ...
      <script src="[https://unpkg.com/htmx.org@1.9.10](https://unpkg.com/htmx.org@1.9.10)"></script>
    </head>
    ```

### Step 2: Core Data Models (POROs)
Create Plain Old Ruby Objects (POROs) in `app/models`.

1.  **Card (`app/models/card.rb`):** An immutable object for cards. The `id` is a required attribute.
    ```ruby
    # Using Ruby 3.2+ Data class for an immutable value object
    Card = Data.define(:id, :name, :data)
    ```
2.  **Deck (`app/models/deck.rb`):** Manages its own state and behaviors.
    ```ruby
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
      
      def find_card(card_id)
        @cards.find { |c| c.id == card_id }
      end
    
      # ... other methods: shuffle!, draw, merge!, etc.
    end
    ```
3.  **SessionState (`app/models/session_state.rb`):** The top-level object to be cached. The `add_deck` method is now responsible for generating a UUID for each card upon creation.
    ```ruby
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
        @decks << new_deck
      end
      
      def find_deck(deck_id)
        @decks.find { |deck| deck.id == deck_id }
      end

      def remove_deck(deck_id)
        @decks.reject! { |deck| deck.id == deck_id }
      end
    end
    ```

### Step 3: Deck Definition and Loading
1.  **Create JSON Files:** Create a directory `config/decks`. The card objects in the JSON **do not** need an `id` field anymore, simplifying deck creation.
    * `config/decks/standard_52.json` (example snippet):
        ```json
        {
          "deck": {
            "name": "Standard 52-Card Deck",
            "cards": [
              { "name": "Ace of Spades" },
              { "name": "2 of Spades" },
              { "name": "3 of Spades" }
            ]
          }
        }
        ```
2.  **DeckLoader Service (`app/services/deck_loader.rb`):** This service reads the JSON files.
    ```ruby
    class DeckLoader
      DECK_PATH = Rails.root.join('config', 'decks')
    
      def self.all_deck_names
        Dir.glob(DECK_PATH.join('*.json')).map { |f| File.basename(f, '.json') }
      end
    
      def self.find(deck_name)
        file_path = DECK_PATH.join("#{deck_name}.json")
        return nil unless File.exist?(file_path)
        JSON.parse(File.read(file_path))
      end
    end
    ```

### Step 4: Controllers and State Management
This step involves setting up the controllers that manage session state and render the main views. We use `before_action` and `after_action` hooks in `ApplicationController` to automatically load and save the game state from the cache for each relevant request.

1.  **ApplicationController (`app/controllers/application_controller.rb`):** Add the state management logic here so all controllers can use it.
    ```ruby
    class ApplicationController < ActionController::Base
      before_action :load_session_state
      after_action :save_session_state
    
      private
    
      def load_session_state
        @session_id = session[:session_id]
        return unless @session_id
        @session_state = Rails.cache.read(@session_id) || SessionState.new
      end
    
      def save_session_state
        return unless @session_id && @session_state
        Rails.cache.write(@session_id, @session_state)
      end
    end
    ```
2.  **SessionsController (`app/controllers/sessions_controller.rb`):** Manages the session lifecycle (creation and termination).
    ```ruby
    class SessionsController < ApplicationController
      skip_before_action :load_session_state, only: [:new, :create]
      skip_after_action :save_session_state, only: [:new, :create, :destroy]
    
      def new
        # Renders a simple form in app/views/sessions/new.html.erb
      end
    
      def create
        session_id = params[:session_id].presence
        if session_id
          session[:session_id] = session_id
          Rails.cache.write(session_id, SessionState.new)
          redirect_to game_path
        else
          flash[:alert] = "Session ID cannot be blank."
          render :new
        end
      end
    
      def destroy
        Rails.cache.delete(session[:session_id]) if session[:session_id]
        session.delete(:session_id)
        redirect_to root_path, notice: "Session terminated."
      end
    end
    ```
3.  **GameController (`app/controllers/game_controller.rb`):** Renders the main game interface.
    ```ruby
    class GameController < ApplicationController
      def show
        redirect_to root_path, alert: 'No active session.' and return unless @session_id
        @available_decks = DeckLoader.all_deck_names
        # Renders app/views/game/show.html.erb automatically.
      end
    end
    ```

### Step 5: Detailed Action Implementation (`DecksController`)
All actions that modify the game state will be handled by the `DecksController`. Each action modifies the `@session_state` object in memory, and the `after_action` hook saves the updated state back to the cache. The actions then render an ERB partial, which HTMX uses to update the specific part of the page that changed.

1.  **Routes (`config/routes.rb`):** Define the routes for all session and deck actions.
    ```ruby
    Rails.application.routes.draw do
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
    ```
2.  **DecksController (`app/controllers/decks_controller.rb`):** Implement the logic for each action.
    ```ruby
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
    ```

### Step 6: Views and Partials
Break the UI into logical, reusable partials that HTMX can target for updates. This prevents full page reloads and creates a responsive user experience.

1.  **Main View (`app/views/game/show.html.erb`):** The main container for the session controls and the decks.
    ```erb
    <h1>Session: <%= @session_id %></h1>
    <p><%= link_to "Terminate Session", session_path, data: { "turbo-method": :delete, "turbo-confirm": "Are you sure?" } %></p>
    
    <div id="controls">
      <h3>Session Controls</h3>
      <%= form_with url: add_deck_path, method: :post do |f| %>
        <%= f.select :deck_name, options_for_select(@available_decks) %>
        <%= f.submit "Add Deck", "hx-post": add_deck_path, "hx-target": "#session-decks", "hx-swap": "innerHTML" %>
      <% end %>
    </div>
    
    <hr>
    
    <div id="session-decks">
      <%= render partial: 'game/session_decks', locals: { session_state: @session_state } %>
    </div>
    ```
2.  **Session Decks Partial (`app/views/game/_session_decks.html.erb`):** This partial renders all decks currently in the session. It's the most common target for HTMX updates, as most actions affect the entire set of decks.
    ```erb
    <% session_state.decks.each do |deck| %>
      <div id="deck_<%= deck.id %>" class="deck-wrapper">
        <%= render partial: 'game/deck', locals: { deck: deck } %>
      </div>
    <% end %>
    ```
3.  **Deck Partial (`app/views/game/_deck.html.erb`):** This partial renders a single deck, including its name, card counts, and all associated action buttons.
    ```erb
    <div class="deck-container">
      <h3><%= deck.name %> (ID: <%= deck.id.split('.').first %>)</h3>
      <p>Cards: <%= deck.cards.count %></p>
      <p>Discard: <%= deck.discard_pile.count %></p>
      
      <button hx-post="<%= shuffle_deck_path(deck.id) %>" hx-target="#deck_<%= deck.id %>" hx-swap="outerHTML">Shuffle</button>
      <button hx-post="<%= shuffle_with_discard_path(deck.id) %>" hx-target="#deck_<%= deck.id %>" hx-swap="outerHTML">Shuffle w/ Discard</button>
      
      <%= form_with url: draw_card_path(deck.id), method: :post, class: "inline-form" do |f| %>
        <%= f.number_field :count, value: 1, min: 1, style: "width: 40px;" %>
        <%= f.submit "Draw", "hx-post": draw_card_path(deck.id), "hx-target": "#session-decks" %>
      <% end %>

      <button hx-delete="<%= remove_deck_path(deck.id) %>" hx-target="#session-decks" hx-confirm="Remove this deck?">Remove Deck</button>
    </div>
    ```

### Step 7: Finalize UI and Styling
The final step is to implement any remaining complex UI control forms (e.g., for moving or merging cards) and apply minimal styling to make the application usable. The focus is on function over form.

1.  **Implement Control Forms:** Add the forms for `move` and `merge` actions to `game/show.html.erb`. These will be standard Rails forms with HTMX attributes to post to the `DecksController` and target the `#session-decks` div for updates.
2.  **Minimal CSS:** Add basic CSS in `app/assets/stylesheets/application.css` for readability. Use flexbox to arrange decks and controls.
    ```css
    body {
      font-family: sans-serif;
      padding: 1rem;
    }
    #session-decks { 
      display: flex; 
      flex-wrap: wrap; 
      gap: 1rem; 
      margin-top: 1rem;
    }
    .deck-container { 
      border: 1px solid #ccc; 
      padding: 1rem;
      border-radius: 8px;
    }
    #controls, .deck-container {
      display: flex;
      flex-direction: column;
      gap: 0.5rem;
    }
    .inline-form {
      display: flex;
      gap: 0.5rem;
    }
    button, input[type="submit"] {
      cursor: pointer;
    }
    ```