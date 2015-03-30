require 'rails_helper'
require 'vcr_helper'

RSpec.describe HomeworkAssistant, :type => :assistant, :vcr => VCR_OPTS do

  let!(:assistant) { FactoryGirl.create :assistant,
                                        code_class_name: 'HomeworkAssistant' }

  let!(:exercises) {
    Content::Routines::ImportExercises.call(tag: 'k12phys-ch04-s01-lo01')
                                      .outputs.exercises
  }

  let!(:exercise_ids) { exercises[1..-2].collect{|e| e.id} }
  let!(:tutor_exercise_count) { 4 } # Adjust if spaced practice changes

  let!(:task_plan) {
    FactoryGirl.create :task_plan, assistant: assistant,
                                   settings: { exercise_ids: exercise_ids }
  }

  let!(:taskees) { 3.times.collect{ FactoryGirl.create(:user) } }
  let!(:tasking_plans) { taskees.collect { |t|
    task_plan.tasking_plans << FactoryGirl.create(
      :tasking_plan, task_plan: task_plan, target: t
    )
  } }

  it 'assigns the exercises chosen by the teacher' do
    tasks = DistributeTasks.call(task_plan).outputs.tasks
    expect(tasks.length).to eq 3

    tasks.each do |task|
      expect(task.taskings.length).to eq 1
      task_steps = task.task_steps
      expect(task_steps.length).to(
        eq exercise_ids.length + tutor_exercise_count
      )

      task_steps[0..exercise_ids.length-1].each_with_index do |task_step, i|
        exercise = exercises[i+1]
        tasked = task_step.tasked
        expect(tasked).to be_a(TaskedExercise)
        expect(tasked.url).to eq(exercise.url)
        expect(tasked.title).to eq(exercise.title)
        expect(tasked.content).to eq(exercise.content)

        task_steps.except(task_step).each do |other_step|
          expect(tasked.content).not_to(
            include(other_step.tasked.content)
          )
        end
      end
    end

    expect(tasks.collect{|t| t.taskings.first.taskee}).to eq taskees
    expect(tasks.collect{|t| t.taskings.first.user}).to eq taskees
  end

  xit 'assigns the exercises chosen by tutor' do
  end

end
