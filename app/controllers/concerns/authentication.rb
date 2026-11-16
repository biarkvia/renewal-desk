module Authentication
  extend ActiveSupport::Concern

  included do
    prepend_before_action :require_authentication
    helper_method :current_user
  end

  private

  def current_user
    current_session&.user
  end

  def current_session
    return @current_session if defined?(@current_session)

    session_id = session[:renewal_session_id]
    @current_session = Session.active.includes(:user).find_by(id: session_id) if session_id
  end

  def require_authentication
    redirect_to new_session_path, status: :see_other unless current_user
  end

  def start_session(user)
    current_session&.destroy!
    reset_session
    @current_session = Session.create!(user: user)
    session[:renewal_session_id] = @current_session.id
  end

  def end_session
    current_session.destroy!
    @current_session = nil
    reset_session
  end
end
