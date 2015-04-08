class TaskedAccessPolicy
  def self.action_allowed?(action, requestor, tasked)
    case action
    when :read, :create, :update, :destroy, :mark_completed, :recover, :refresh
      requestor.is_human? &&
      DoesTaskingExist[task_component: tasked, user: requestor]
    else
      false
    end
  end
end
