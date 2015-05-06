module Api::V1

  # Represents the information that a user should be able to view about their profile
  class UserProfileRepresenter < ::Roar::Decorator

    include ::Roar::JSON

    property :name

  end
end
