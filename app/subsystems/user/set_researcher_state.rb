module User
  class SetResearcherState
    lev_routine

    protected

    def exec(user:, researcher: false)
      return if (researcher && user.is_researcher?) || \
                (!researcher && !user.is_researcher?)

      profile = user.to_model
      researcher ? profile.create_researcher! : profile.researcher.destroy
    end
  end
end
