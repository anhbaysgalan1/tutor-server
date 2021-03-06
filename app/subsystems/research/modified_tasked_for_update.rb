class Research::ModifiedTaskedForUpdate

  lev_routine express_output: :tasked

  def exec(tasked:)
    outputs.tasked = tasked
    task = tasked.task_step.task

    task.research_study_brains.each do |brain|
      next unless brain.should_execute? :modified_tasked_for_update
      task.research_cohorts.each do |cohort|
        outputs.merge!(
          brain.modified_tasked_for_update(cohort: cohort, tasked: tasked)
        )
      end
    end
  end

end
