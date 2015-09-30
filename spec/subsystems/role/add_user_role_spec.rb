require 'rails_helper'

describe Role::AddUserRole, type: :routine do
  context "when adding a new user role" do
    it "succeeds" do
      role = Entity::Role.create!
      profile = FactoryGirl.create(:user_profile)
      strategy = User::Strategies::Direct::User.new(profile)
      user = User::User.new(strategy: strategy)

      result = nil
      expect {
        result = Role::AddUserRole.call(user: user, role: role)
      }.to change { Role::Models::RoleUser.count }.by(1)
      expect(result.errors).to be_empty
    end
  end
  context "when adding a existing user role" do
    it "fails" do
      role = Entity::Role.create!
      profile = FactoryGirl.create(:user_profile)
      strategy = User::Strategies::Direct::User.new(profile)
      user = User::User.new(strategy: strategy)

      result = nil
      expect {
        result = Role::AddUserRole.call(user: user, role: role)
      }.to change { Role::Models::RoleUser.count }.by(1)
      expect(result.errors).to be_empty

      expect {
        result = Role::AddUserRole.call(user: user, role: role)
      }.to raise_error
    end
  end
end
