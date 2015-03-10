module Tutor::SubSystems

  module AssociationExtensions

    extend ActiveSupport::Concern

    module ClassMethods

      def belongs_to(name, scope = nil, options = {})
        set_subsystem_options(name, scope, options, true)
        super
      end

      def has_one(name, scope = nil, options = {})
        set_subsystem_options(name, scope, options)
        super
      end

      def has_many(name, scope = nil, options = {}, &extension)
        set_subsystem_options(name, scope, options)
        super
      end

      private

      def set_subsystem_options(association_name, scope, options, is_belongs_to=false)
        # While rarely used, assocations can be created with a
        # scope to limit the record, `belongs_to :user, ->{ where(id: 2) }, class_name: "MyUser"`
        # To cope with having either two or three arguments, Rails inspects the scope arguemnt.
        # If it's a Hash, then It's considered the options and the options argument is ignored.
        options = scope if scope.is_a?(Hash)
        subsystem_name = options.delete(:subsystem).to_s
        return if ['none','ignore'].include?(subsystem_name)

        my_subsystem_name = self.name.deconstantize.underscore
        return unless Tutor::SubSystems.valid_name?(my_subsystem_name)

        # if the :subsystem wasn't specified, default to the current model's subsystem
        subsystem_name = my_subsystem_name if subsystem_name.blank?

        options[:class_name] ||= "::#{subsystem_name.camelize}::#{association_name.to_s.camelize.singularize}"
        if is_belongs_to
          options[:foreign_key] ||= "#{subsystem_name}_#{association_name.to_s.underscore}_id"
        else
          class_name = self.name.demodulize.underscore
          options[:foreign_key] ||= "#{subsystem_name}_#{class_name}_id"
        end
        options
      end

    end
  end
end
