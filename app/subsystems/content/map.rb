module Content
  class Map

    include Wrapper

    class << self
      # Create a new map or return nil if it cannot be created
      def create(from_ecosystems:, to_ecosystem:,
                 strategy_class: ::Content::Strategies::Generated::Map)
        from_arr = verify_and_return [from_ecosystems].flatten.compact, klass: ::Content::Ecosystem
        to = verify_and_return to_ecosystem, klass: ::Content::Ecosystem
        verify_and_return strategy_class.create(from_ecosystems: from_ecosystems,
                                                to_ecosystem: to_ecosystem),
                          klass: ::Content::Map, allow_nil: true, error: StrategyError
      end

      # Create a new map or error out if it cannot be created or is invalid
      def create!(from_ecosystems:, to_ecosystem:,
                  strategy_class: ::Content::Strategies::Generated::Map)
        from_arr = verify_and_return [from_ecosystems].flatten.compact, klass: ::Content::Ecosystem
        to = verify_and_return to_ecosystem, klass: ::Content::Ecosystem
        verify_and_return strategy_class.create!(from_ecosystems: from_ecosystems,
                                                 to_ecosystem: to_ecosystem),
                          klass: ::Content::Map, error: StrategyError
      end

      # Find an existing map or return nil if it is missing
      def find(from_ecosystems:, to_ecosystem:,
               strategy_class: ::Content::Strategies::Generated::Map)
        from_arr = verify_and_return [from_ecosystems].flatten.compact, klass: ::Content::Ecosystem
        to = verify_and_return to_ecosystem, klass: ::Content::Ecosystem
        verify_and_return strategy_class.find(from_ecosystems: from_ecosystems,
                                              to_ecosystem: to_ecosystem),
                          klass: ::Content::Map, allow_nil: true, error: StrategyError
      end

      # Find an existing map or error out if it is missing or is invalid
      def find!(from_ecosystems:, to_ecosystem:,
                strategy_class: ::Content::Strategies::Generated::Map)
        from_arr = verify_and_return [from_ecosystems].flatten.compact, klass: ::Content::Ecosystem
        to = verify_and_return to_ecosystem, klass: ::Content::Ecosystem
        verify_and_return strategy_class.find!(from_ecosystems: from_ecosystems,
                                               to_ecosystem: to_ecosystem),
                          klass: ::Content::Map, error: StrategyError
      end
    end

    # Returns a hash that maps the given ::Content::Exercises' ids
    # to ::Content::Pages in the to_ecosystem
    def map_exercises_to_pages(exercises:)
      ex_arr = verify_and_return [exercises].flatten.compact, klass: ::Content::Exercise
      map = verify_and_return @strategy.map_exercises_to_pages(exercises: ex_arr),
                              klass: Hash, error: StrategyError
      verify_and_return map.keys, klass: Integer, error: StrategyError
      verify_and_return map.values, klass: ::Content::Page, error: StrategyError
      map
    end

    def valid?
      !!@strategy.valid?
    end

  end
end
