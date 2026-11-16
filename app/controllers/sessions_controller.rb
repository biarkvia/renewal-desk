class SessionsController < ApplicationController
  skip_before_action :require_authentication, only: [ :new, :create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { render_rate_limit }

  def new
    redirect_to root_path if current_user
  end

  def create
    @email_address = params[:email_address].presence if params[:email_address].is_a?(String)
    password = params[:password]
    user = User.authenticate_by(email_address: @email_address, password: password) if @email_address && password.is_a?(String)

    if user
      start_session(user)
      redirect_to root_path, status: :see_other
    else
      @sign_in_error = "Check your email address and password."
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    end_session
    redirect_to new_session_path, status: :see_other
  end

  private

  def render_rate_limit
    @sign_in_error = "Too many sign-in attempts. Try again in a few minutes."
    render :new, status: :too_many_requests
  end
end
