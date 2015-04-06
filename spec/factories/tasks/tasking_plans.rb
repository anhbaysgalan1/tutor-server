FactoryGirl.define do
  factory :tasks_tasking_plan, class: '::Tasks::Models::TaskingPlan' do
    association :target, factory: :entity_course
    association :task_plan, factory: :tasks_task_plan
  end
end