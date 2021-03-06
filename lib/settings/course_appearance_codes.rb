module Settings
  class CourseAppearanceCodes

    class << self
      include Enumerable

      def each
        Settings::Db.store.course_appearance_codes.each{|code| yield code }
      end

    end

  end
end
