class Admin::UsersController < Admin::BaseController
  before_action :get_user, only: [:edit, :update]

  def index
    @per_page = 30
    @user_search = User::SearchUsers[search: "%#{params[:search_term]}%",
                                     page: params[:page],
                                     per_page: @per_page]

    respond_to do |format|
      format.html
      format.json { render json: @user_search }
    end
  end

  def create
    handle_with(
      Admin::UsersCreate,
      success: ->(*) {
        flash[:notice] = 'The user has been added.'
        redirect_to admin_users_path(
          search_term: @handler_result.outputs[:profile].username
        )
      },
      failure: ->(*) {
        flash[:error] = 'Invalid user information.'
        redirect_to new_admin_user_path
      }
    )
  end

  def edit
  end

  def update
    handle_with(
      Admin::UsersUpdate,
      profile: @user,
      success: ->(*) {
        flash[:notice] = 'The user has been updated.'
        redirect_to admin_users_path(
          search_term: @handler_result.outputs[:account].username
        )
      },
      failure: ->(*) {
        flash[:error] = 'Invalid user information.'
        redirect_to new_admin_user_path
      }
    )
  end

  def become
    account = GetAccount[id: params[:id]]
    sign_in(account)
    redirect_to root_path
  end

  private

  def get_user
    @user = User::User.find(params[:id])
  end
end
