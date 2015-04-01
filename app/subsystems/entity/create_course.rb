class Entity::CreateCourse
  lev_routine

  protected

  def exec
    course = Entity::Models::Course.create
    transfer_errors_from(course, {type: :verbatim}, true)
    outputs[:course] = course
  end
end