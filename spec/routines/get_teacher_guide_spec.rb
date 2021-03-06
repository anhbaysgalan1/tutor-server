require 'rails_helper'
require 'vcr_helper'
require 'database_cleaner'

RSpec.describe GetTeacherGuide, type: :routine do

  before(:all) do
    @course = FactoryBot.create :course_profile_course

    @period = FactoryBot.create :course_membership_period, course: @course
    @second_period = FactoryBot.create :course_membership_period, course: @course

    @teacher = FactoryBot.create(:user)
    @student = FactoryBot.create(:user)
    @second_student = FactoryBot.create(:user)

    @role = AddUserAsPeriodStudent[period: @period, user: @student]
    @second_role = AddUserAsPeriodStudent[period: @second_period, user: @second_student]
    @teacher_role = AddUserAsCourseTeacher[course: @course, user: @teacher]
  end

  let(:clue_matcher) do
    a_hash_including(
      minimum: kind_of(Numeric),
      most_likely: kind_of(Numeric),
      maximum: kind_of(Numeric),
      is_real: be_in([true, false])
    )
  end

  context 'without work' do

    before(:all) do
      @role.reload
      @second_role.reload
      @teacher_role.reload

      DatabaseCleaner.start
      book = FactoryBot.create :content_book, title: 'Physics (Demo)'
      ecosystem = Content::Ecosystem.new(strategy: book.ecosystem.wrap)
      AddEcosystemToCourse[course: @course, ecosystem: ecosystem]
    end

    after(:all) { DatabaseCleaner.clean }

    context 'without periods' do
      before(:all) do
        DatabaseCleaner.start
        @period.destroy
        @second_period.destroy
      end

      after(:all) { DatabaseCleaner.clean }

      it 'returns an empty array' do
        expect(described_class[role: @teacher_role.reload]).to eq []
      end
    end

    context 'with periods' do
      it 'returns an empty guide per period' do
        guide = described_class[role: @teacher_role.reload]

        expect(guide).to match [
          {
            period_id: @period.id,
            title: 'Physics (Demo)',
            page_ids: [],
            children: []
          },
          {
            period_id: @second_period.id,
            title: 'Physics (Demo)',
            page_ids: [],
            children: []
          }
        ]
      end
    end

  end

  context 'with work' do

    before(:all) do
      @role.reload
      @second_role.reload
      @teacher_role.reload

      VCR.use_cassette("GetCourseGuide/setup_course_guide", VCR_OPTS) do
        capture_stdout do
          CreateStudentHistory[course: @course, roles: [@role, @second_role]]
        end
      end
    end

    it 'returns all course guide periods for teachers' do
      guide = described_class[role: @teacher_role]

      expect(guide).to match [
        {
          period_id: @period.id,
          title: 'Physics (Demo)',
          page_ids: [kind_of(Integer)]*6,
          children: [kind_of(Hash)]*2
        },
        {
          period_id: @second_period.id,
          title: 'Physics (Demo)',
          page_ids: [kind_of(Integer)]*6,
          children: [kind_of(Hash)]*2
        }
      ]
    end

    it 'includes chapter stats for each period' do
      guide = described_class[role: @teacher_role]

      period_1_chapter_1 = guide.first['children'].first
      expect(period_1_chapter_1).to match(
        title: "Acceleration",
        book_location: [3],
        student_count: 1,
        questions_answered_count: 2,
        clue: clue_matcher,
        page_ids: [kind_of(Integer)]*2,
        children: [kind_of(Hash)]*2
      )

      period_1_chapter_2 = guide.first['children'].second
      expect(period_1_chapter_2).to match(
        title: "Force and Newton's Laws of Motion",
        book_location: [4],
        student_count: 1,
        questions_answered_count: 7,
        clue: clue_matcher,
        page_ids: [kind_of(Integer)]*4,
        children: [kind_of(Hash)]*4
      )

      period_2_chapter_1 = guide.second['children'].first
      expect(period_2_chapter_1).to match(
        title: "Acceleration",
        book_location: [3],
        student_count: 1,
        questions_answered_count: 5,
        clue: clue_matcher,
        page_ids: [kind_of(Integer)]*2,
        children: [kind_of(Hash)]*2
      )

      period_2_chapter_2 = guide.second['children'].second
      expect(period_2_chapter_2).to match(
        title: "Force and Newton's Laws of Motion",
        book_location: [4],
        student_count: 1,
        questions_answered_count: 5,
        clue: clue_matcher,
        page_ids: [kind_of(Integer)]*4,
        children: [kind_of(Hash)]*4
      )
    end

    it 'includes page stats for each period and each chapter' do
      guide = described_class[role: @teacher_role]

      period_1_chapter_1_pages = guide.first['children'].first['children']
      expect(period_1_chapter_1_pages).to match [
        {
          title: "Acceleration",
          book_location: [3, 1],
          student_count: 1,
          questions_answered_count: 2,
          clue: clue_matcher,
          page_ids: [kind_of(Integer)]
        },
        {
          title: "Representing Acceleration with Equations and Graphs",
          book_location: [3, 2],
          student_count: 1,
          questions_answered_count: 0,
          clue: clue_matcher,
          page_ids: [kind_of(Integer)]
        }
      ]

      period_1_chapter_2_pages = guide.first['children'].second['children']
      expect(period_1_chapter_2_pages).to match [
        {
          title: "Force",
          book_location: [4, 1],
          student_count: 1,
          questions_answered_count: 2,
          clue: clue_matcher,
          page_ids: [kind_of(Integer)]
        },
        {
          title: "Newton's First Law of Motion: Inertia",
          book_location: [4, 2],
          student_count: 1,
          questions_answered_count: 5,
          clue: clue_matcher,
          page_ids: [kind_of(Integer)]
        },
        {
          title: "Newton's Second Law of Motion",
          book_location: [4, 3],
          student_count: 1,
          questions_answered_count: 0,
          clue: clue_matcher,
          page_ids: [kind_of(Integer)]
        },
        {
          title: "Newton's Third Law of Motion",
          book_location: [4, 4],
          student_count: 1,
          questions_answered_count: 0,
          clue: clue_matcher,
          page_ids: [kind_of(Integer)]
        }
      ]

      period_2_chapter_1_pages = guide.second['children'].first['children']
      expect(period_2_chapter_1_pages).to match [
        {
          title: "Acceleration",
          book_location: [3, 1],
          student_count: 1,
          questions_answered_count: 5,
          clue: clue_matcher,
          page_ids: [kind_of(Integer)]
        },
        {
          title: "Representing Acceleration with Equations and Graphs",
          book_location: [3, 2],
          student_count: 1,
          questions_answered_count: 0,
          clue: clue_matcher,
          page_ids: [kind_of(Integer)]
        }
      ]

      period_2_chapter_2_pages = guide.second['children'].second['children']
      expect(period_2_chapter_2_pages).to match [
        {
          title: "Force",
          book_location: [4, 1],
          student_count: 1,
          questions_answered_count: 0,
          clue: clue_matcher,
          page_ids: [kind_of(Integer)]
        },
        {
          title: "Newton's First Law of Motion: Inertia",
          book_location: [4, 2],
          student_count: 1,
          questions_answered_count: 5,
          clue: clue_matcher,
          page_ids: [kind_of(Integer)]
        },
        {
          title: "Newton's Second Law of Motion",
          book_location: [4, 3],
          student_count: 1,
          questions_answered_count: 0,
          clue: clue_matcher,
          page_ids: [kind_of(Integer)]
        },
        {
          title: "Newton's Third Law of Motion",
          book_location: [4, 4],
          student_count: 1,
          questions_answered_count: 0,
          clue: clue_matcher,
          page_ids: [kind_of(Integer)]
        }
      ]
    end

  end

end
