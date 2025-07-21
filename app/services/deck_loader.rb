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
