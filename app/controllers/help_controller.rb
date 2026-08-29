class HelpController < ApplicationController
  before_action :check_valid_login

  def index
    @user = User.find(session[:user_id])
    @languages = Language.where.not(name: ['archive', 'viva']).order(:pretty_name)
  end
end
