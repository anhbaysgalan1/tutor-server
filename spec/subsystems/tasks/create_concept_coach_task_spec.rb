require 'rails_helper'
require 'vcr_helper'

RSpec.describe Tasks::CreateConceptCoachTask, type: :routine do
  let(:user)             { FactoryGirl.create :user }
  let(:period)           { FactoryGirl.create :course_membership_period }
  let(:role)             { AddUserAsPeriodStudent[user: user, period: period] }
  let(:page_model)       { FactoryGirl.create :content_page }
  let(:page)             { Content::Page.new(strategy: page_model.wrap) }

  let(:exercise_model_1) { FactoryGirl.create :content_exercise, page: page_model }
  let(:exercise_model_2) { FactoryGirl.create :content_exercise, page: page_model }
  let(:exercise_model_3) { FactoryGirl.create :content_exercise, page: page_model }
  let(:exercise_model_4) { FactoryGirl.create :content_exercise, page: page_model }
  let(:exercise_model_5) { FactoryGirl.create :content_exercise, page: page_model }

  let(:exercises)        do
    [exercise_model_5, exercise_model_4, exercise_model_3,
     exercise_model_2, exercise_model_1].map do |exercise_model|
      Content::Exercise.new(strategy: exercise_model.wrap)
    end
  end

  let(:group_types) do
    [:core_group, :core_group, :core_group, :spaced_practice_group, :spaced_practice_group]
  end

  it 'creates a task containing the given exercises in the proper order' do
    task = nil
    expect{ task = described_class[role: role, page: page, exercises: exercises,
                                   group_types: group_types] }.to(
      change{ Tasks::Models::Task.count }.by(1)
    )
    expect(task.concept_coach?).to eq true
    expect(task.tasked_exercises.map(&:content_exercise_id)).to eq exercises.map(&:id)
    expect(task.task_steps.map(&:group_type)).to eq group_types.map(&:to_s)
  end

  it 'creates a ConceptCoachTask object' do
    task = nil
    expect{ task = described_class[role: role, page: page, exercises: exercises,
                                   group_types: group_types] }.to(
      change{ Tasks::Models::ConceptCoachTask.count }.by(1)
    )
    cc_task = Tasks::Models::ConceptCoachTask.order(:created_at).last
    expect(cc_task.page).to eq page_model
    expect(cc_task.role).to eq role
    expect(cc_task.task).to eq task
    expect(task.taskings.first.role).to eq role
  end
end
