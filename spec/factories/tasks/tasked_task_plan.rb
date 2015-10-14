FactoryGirl.define do
  factory :tasked_task_plan, parent: :tasks_task_plan do

    type 'reading'

    assistant do
      Tasks::Models::Assistant.find_by(
        code_class_name: 'Tasks::Assistants::IReadingAssistant'
      ) || FactoryGirl.create(
        :tasks_assistant, code_class_name: 'Tasks::Assistants::IReadingAssistant'
      )
    end

    transient do
      number_of_students 10
    end

    ecosystem do
      cnx_page = OpenStax::Cnx::V1::Page.new(
        hash: { 'id' => '640e3e84-09a5-4033-b2a7-b7fe5ec29dc6',
                'title' => 'Newton\'s First Law of Motion: Inertia' }
      )

      chapter = FactoryGirl.create :content_chapter

      require File.expand_path('../../../vcr_helper', __FILE__)

      VCR.use_cassette("TaskedTaskPlan/with_inertia", VCR_OPTS) do
        @page = Content::Routines::ImportPage[cnx_page: cnx_page, chapter: chapter,
                                              book_location: [1, 1]]
      end

      Content::Routines::PopulateExercisePools[book: chapter.book]

      ecosystem_model = chapter.book.ecosystem
      ecosystem_strategy = ::Content::Strategies::Direct::Ecosystem.new(ecosystem_model)
      ecosystem = ::Content::Ecosystem.new(strategy: ecosystem_strategy)

      AddEcosystemToCourse[course: owner, ecosystem: ecosystem]

      ecosystem_model
    end

    settings { { page_ids: [@page.id.to_s] } }

    after(:build) do |task_plan, evaluator|
      course = task_plan.owner
      period = course.periods.first || CreatePeriod[course: course]

      evaluator.number_of_students.times do
        profile = create :user_profile
        strategy = User::Strategies::Direct::User.new(profile)
        user = User::User.new(strategy: strategy)
        role = Role::GetDefaultUserRole[user]
        CourseMembership::AddStudent.call(period: period, role: role)
      end

      task_plan.tasking_plans = [build(:tasks_tasking_plan, task_plan: task_plan, target: period)]
    end

    after(:create) do |task_plan, evaluator|
      DistributeTasks.call(task_plan)
      task_plan.reload
    end
  end
end
