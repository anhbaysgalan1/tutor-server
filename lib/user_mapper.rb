require './app/subsystems/user_profile/models/profile'

module UserMapper

  def self.account_to_user(account)
    return UserProfile::Profile.anonymous if account.is_anonymous?

    user = UserProfile::Profile.where(account_id: account.id).first
    return user if user.present?

    outcome = CreateUser.call(account)
    raise outcome.errors.first.message unless outcome.errors.none?

    outcome.outputs.user
  end

  def self.user_to_account(user)
    user.account
  end

end
