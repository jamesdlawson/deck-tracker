class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

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
