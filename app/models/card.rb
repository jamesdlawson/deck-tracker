Card = Data.define(:id, :name, :data) do
  include comparable


  def <=>(other)
    return unless other.is_a?(self.class)

    self.id <=> other.id
  end
end
