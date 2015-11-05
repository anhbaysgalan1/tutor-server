require 'rails_helper'

RSpec.describe AuthController, type: :controller do

  let(:user)        { FactoryGirl.create(:user) }

  context "as an non-signed in user" do

    it 'allows access to iframe start and redirects to accounts' do
      get :iframe_start
      expect(session[:accounts_return_to]).to eq(after_iframe_authentication_url)
      expect(response).to redirect_to(controller.openstax_accounts.login_url)
    end

    it 'disallows access to iframe finish' do
      get :iframe_finish
      expect(response).to have_http_status(:forbidden)
    end

  end

  context "as an signed in user" do
    render_views

    it 'allows access to iframe start and simply renders status info' do
      controller.sign_in user
      get :iframe_start
      expect(session[:accounts_return_to]).to be_nil
      expect(assigns(:status)).not_to be_nil
      expect(response.body).to include('window.parent.postMessage')
    end

    it 'allows access to iframe finish and sets status info' do
      controller.sign_in user
      get :iframe_finish
      expect(response).to have_http_status(:ok)
      expect(assigns(:status)).not_to be_nil
      expect(response.body).to include('window.parent.postMessage')
    end

  end

end