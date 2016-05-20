module Tasks
  class CreatePracticeWidgetTask
    lev_routine express_output: :task

    uses_routine BuildTask,
      translations: { outputs: { type: :verbatim } },
      as: :build_task

    protected

    def exec(exercises:, task_type: :mixed_practice, related_content_array: [])
      run(:build_task, task_type: task_type, title: 'Practice')

      exercises.each_with_index do |exercise, ii|
        TaskExercise.call(exercise: exercise, task: outputs.task) do |step|
          step.add_related_content(related_content_array[ii])
        end
      end

      outputs.task.save!
    end

  end
end
