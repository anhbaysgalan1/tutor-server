module Content
  module Strategies
    module Generated
      class Map

        class << self
          def create(from_ecosystems:, to_ecosystem:)
            strategy = new(from_ecosystems: from_ecosystems, to_ecosystem: to_ecosystem)
            ::Content::Map.new(strategy: strategy)
          end

          def create!(from_ecosystems:, to_ecosystem:)
            create(from_ecosystems: from_ecosystems, to_ecosystem: to_ecosystem).tap do |map|
              raise(
                Content::MapInvalidError, "Cannot generate a valid ecosystem map from " +
                "[#{from_ecosystems.map(&:title).join(', ')}] to #{to_ecosystem.title}"
              ) unless map.valid?
            end
          end

          alias_method :find, :create

          alias_method :find!, :create!
        end

        def initialize(from_ecosystems:, to_ecosystem:)
          @from_ecosystems = from_ecosystems
          @to_ecosystem = to_ecosystem

          @page_id_to_page_map = {}
          @exercise_id_to_page_map = {}
          @page_id_to_pool_exercises_map = {}
        end

        def map_pages_to_pages(pages:)
          page_ids = pages.map(&:id)

          initialize_page_id_to_page_map_for_the_to_ecosystem

          mapped_pages = @page_id_to_page_map.slice(*page_ids)
          unmapped_page_ids = page_ids - mapped_pages.keys

          return mapped_pages if unmapped_page_ids.empty?

          unmapped_page_models = Content::Models::Page
            .joins(tags: :same_value_tags)
            .where(id: unmapped_page_ids,
                   tags: {
                     content_ecosystem_id: @from_ecosystems.map(&:id),
                     tag_type: mapping_tag_types,
                     same_value_tags: {
                       content_ecosystem_id: @to_ecosystem.id,
                       tag_type: mapping_tag_types
                     }
                   })
            .preload(tags: {same_value_tags: :pages})
            .uniq

          unmapped_page_models.each do |page_model|
            mapping_tags = page_model.tags.select(&:mapping?)
            tags_across_ecosystems = mapping_tags.flat_map(&:same_value_tags).select(&:mapping?)
            page_models = tags_across_ecosystems.flat_map(&:pages).uniq
            ecosystem_pages = page_models.map{ |pm| @page_id_to_page_map[pm.id] }.compact.uniq

            # It could happen in theory that a page maps to 2 pages,
            # but for now we don't handle that case
            # since it's hard to figure out what to do for the dashboard/scores
            @page_id_to_page_map[page_model.id] = \
              ecosystem_pages.size == 1 ? ecosystem_pages.first : nil
          end

          mapped_pages.merge(@page_id_to_page_map.slice(*unmapped_page_ids))
        end

        def map_exercises_to_pages(exercises:)
          exercise_ids = exercises.map(&:id)
          mapped_exercises = @exercise_id_to_page_map.slice(*exercise_ids)
          unmapped_exercise_ids = exercise_ids - mapped_exercises.keys

          return mapped_exercises if unmapped_exercise_ids.empty?

          initialize_page_id_to_page_map_for_the_to_ecosystem

          unmapped_exercise_models = Content::Models::Exercise
            .joins(tags: :same_value_tags)
            .where(id: unmapped_exercise_ids,
                   tags: {
                     content_ecosystem_id: @from_ecosystems.map(&:id),
                     tag_type: mapping_tag_types,
                     same_value_tags: {
                       content_ecosystem_id: @to_ecosystem.id,
                       tag_type: mapping_tag_types
                     }
                   })
            .preload(tags: {same_value_tags: :pages})
            .uniq

          unmapped_exercise_models.each do |exercise_model|
            mapping_tags = exercise_model.tags.select(&:mapping?)
            tags_across_ecosystems = mapping_tags.flat_map(&:same_value_tags).select(&:mapping?)
            page_models = tags_across_ecosystems.flat_map(&:pages).uniq
            ecosystem_pages = page_models.map{ |cp| @page_id_to_page_map[cp.id] }.compact.uniq

            # We only allow each exercise to map to 1 page
            @exercise_id_to_page_map[exercise_model.id] = \
              ecosystem_pages.size == 1 ? ecosystem_pages.first : nil
          end

          mapped_exercises.merge(@exercise_id_to_page_map.slice(*unmapped_exercise_ids))
        end

        def map_pages_to_exercises(pages:, pool_type: :all_exercises)
          pool_method = "#{pool_type}_pool".to_sym
          page_ids = pages.map(&:id)
          @page_id_to_pool_exercises_map[pool_type] ||= {}
          mapped_pages = @page_id_to_pool_exercises_map[pool_type].slice(*page_ids)
          unmapped_page_ids = page_ids - mapped_pages.keys

          return mapped_pages if unmapped_page_ids.empty?

          @exercise_id_to_exercise_map ||= @to_ecosystem.exercises
                                                        .each_with_object({}) do |exercise, hash|
            hash[exercise.id] = exercise
          end

          unmapped_page_models = Content::Models::Page
            .joins(tags: :same_value_tags)
            .where(id: unmapped_page_ids,
                   tags: {
                     content_ecosystem_id: @from_ecosystems.map(&:id),
                     tag_type: mapping_tag_types,
                     same_value_tags: {
                       content_ecosystem_id: @to_ecosystem.id,
                       tag_type: mapping_tag_types
                     }
                   })
            .preload(tags: {same_value_tags: [:exercises, { pages: pool_method }]})
            .uniq

          unmapped_page_models.each do |page_model|
            mapping_tags = page_model.tags.select(&:mapping?)
            tags_across_ecosystems = mapping_tags.flat_map(&:same_value_tags).select(&:mapping?)

            tag_exercises = tags_across_ecosystems.flat_map(&:exercises).uniq
            tag_pages = tags_across_ecosystems.flat_map(&:pages).uniq

            pools = tag_pages.map{ |page| page.send pool_method }
            pool_exercises = pools.flat_map(&:exercises)

            exercise_models = tag_exercises & pool_exercises
            ecosystem_exercises = exercise_models.map do |ce|
              @exercise_id_to_exercise_map[ce.id]
            end.compact

            @page_id_to_pool_exercises_map[pool_type][page_model.id] = ecosystem_exercises
          end

          # The remaining pages could not be mapped and thus map to empty arrays of exercises
          untagged_page_ids = unmapped_page_ids - unmapped_page_models.map(&:id)

          @page_id_to_pool_exercises_map[pool_type] = untagged_page_ids
            .each_with_object(@page_id_to_pool_exercises_map[pool_type]) do |page_id, hash|
            hash[page_id] = []
          end

          mapped_pages.merge(@page_id_to_pool_exercises_map[pool_type].slice(*unmapped_page_ids))
        end

        def valid?
          return @valid unless @valid.nil?

          all_exercises = @from_ecosystems.flat_map(&:exercises)
          all_exercises_map = map_exercises_to_pages(exercises: all_exercises)

          all_pages = @from_ecosystems.flat_map(&:pages)
          all_pages_map = map_pages_to_exercises(pages: all_pages, pool_type: :all_exercises)

          # Valid if:
          # 1- All Exercises in the old Ecosystem map to one Page in the new Ecosystem
          # 2- All Pages in the old Ecosystem map to an array of Exercises in the new Ecosystem
          #    (can be empty)
          @valid = Set.new(all_exercises_map.keys) == Set.new(all_exercises.map(&:id)) && \
                   Set.new(all_exercises_map.values).subset?(Set.new(@to_ecosystem.pages)) && \
                   Set.new(all_pages_map.keys) == Set.new(all_pages.map(&:id)) && \
                   Set.new(all_pages_map.values.flatten).subset?(Set.new(@to_ecosystem.exercises))
        end

        protected

        def initialize_page_id_to_page_map_for_the_to_ecosystem
          @page_id_to_page_map = @to_ecosystem.pages.each_with_object({}) do |page, hash|
            hash[page.id] = page
          end if @page_id_to_page_map.blank?
        end

        def mapping_tag_types
          @mapping_tag_types ||= Content::Models::Tag::MAPPING_TAG_TYPES.map do |type|
            Content::Models::Tag.tag_types[type]
          end
        end

      end
    end
  end
end
