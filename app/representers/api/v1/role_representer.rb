module Api::V1
  class RoleRepresenter < Roar::Decorator

    include Roar::JSON
    include Representable::Coercion

    property :id,
             type: String,
             readable: true,
             writeable: false,
             schema_info: { required: true }

    property :type,
             type: String,
             readable: true,
             writeable: false,
             schema_info: { required: true }

    property :joined_at,
             type: String,
             readable: true,
             writeable: false,
             getter: ->(*) { DateTimeUtilities.to_api_s(created_at) },
             schema_info: { required: true }

  end
end
