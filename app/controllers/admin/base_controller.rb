class Admin::BaseController < ApplicationController
  before_filter :authenticate_admin!

  layout 'admin'

  protected

  def authenticate_admin!
    raise SecurityTransgression unless current_user.is_admin?
  end
end
