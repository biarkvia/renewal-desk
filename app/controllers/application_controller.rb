class ApplicationController < ActionController::Base
  include Authentication

  before_action :no_store
  protect_from_forgery with: :exception
end
