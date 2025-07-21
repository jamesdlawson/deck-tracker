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
