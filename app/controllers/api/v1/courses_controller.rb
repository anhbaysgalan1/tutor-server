class Api::V1::CoursesController < Api::V1::ApiController

  resource_description do
    api_versions "v1"
    short_description 'Represents a course in the system'
    description <<-EOS
      Course description to be written...
    EOS
  end

  api :GET, '/courses', 'Returns courses'
  description <<-EOS
    Returns courses in the system, and the user who requested them is shown
    their own roles related to their courses
    #{json_schema(Api::V1::CoursesRepresenter, include: :readable)}
  EOS
  def index
    courses = Domain::ListCourses.call(user: current_human_user.entity_user,
                                       with: :roles)
                                 .outputs.courses
    respond_with courses, represent_with: Api::V1::CoursesRepresenter
  end

  api :GET, '/courses/:course_id/readings', 'Returns a course\'s readings'
  description <<-EOS
    Returns a hierarchical listing of a course's readings.  A course is currently limited to
    only one book.  Inside each book there can be units or chapters (parts), and eventually
    parts (normally chapters) contain pages that have no children.

    #{json_schema(Api::V1::BookTocRepresenter, include: :readable)}
  EOS
  def readings
    course = Entity::Course.find(params[:id])

    # For the moment, we're assuming just one book per course
    books = CourseContent::GetCourseBooks.call(course: course).outputs.books
    raise NotYetImplemented if books.count > 1

    toc = Content::VisitBook[book: books.first, visitor_names: :toc]
    respond_with toc, represent_with: Api::V1::BookTocRepresenter
  end

  api :GET, '/courses/:course_id/exercises',
            "Returns a course\'s exercises, filtered by the page_ids param"
  description <<-EOS
    Returns a list of exercises tagged with LO's matching the given pages.
    If no page_ids are specified, returns an empty array.

    #{json_schema(Api::V1::ExerciseSearchRepresenter, include: :readable)}
  EOS
  def exercises
    course = Entity::Course.find(params[:id])
    OSU::AccessPolicy.require_action_allowed!(:exercises,
                                              current_api_user,
                                              course)

    los = Content::GetPageLos[page_ids: params[:page_ids]]
    outputs = Domain::SearchLocalExercises.call(tag: los, match_count: 1)
                                          .outputs

    respond_with outputs, represent_with: Api::V1::ExerciseSearchRepresenter
  end

  api :GET, '/courses/:course_id/plans', 'Returns a course\'s plans'
  description <<-EOS
    #{json_schema(Api::V1::TaskPlanSearchRepresenter, include: :writeable)}
  EOS
  def plans
    course = Entity::Course.find(params[:id])
    # OSU::AccessPolicy.require_action_allowed!(:task_plans, current_api_user, course)

    out = GetCourseTaskPlans.call(course: course).outputs
    respond_with out, represent_with: Api::V1::TaskPlanSearchRepresenter
  end

  api :GET, '/courses/:course_id/tasks', 'Gets all course tasks assigned to the role holder making the request'
  description <<-EOS
    #{json_schema(Api::V1::TaskSearchRepresenter, include: :readable)}
  EOS
  def tasks
    # No authorization is necessary because if the user isn't authorized, they'll just get
    # back an empty list of tasks
    course = Entity::Course.find(params[:id])
    tasks = Domain::GetCourseUserTasks[course: course,
                                       user: current_human_user.entity_user]
    output = Hashie::Mash.new('items' => tasks.collect{|t| t.task})
    respond_with output, represent_with: Api::V1::TaskSearchRepresenter
  end

  api :GET, '/courses/:course_id/events', 'Gets all events for a given course'
  description <<-EOS
    #{json_schema(Api::V1::CourseEventsRepresenter, include: :readable)}
  EOS
  def events
    course = Entity::Course.find(params[:id])
    outputs = GetUserCourseEvents.call(user: current_human_user.entity_user, course: course).outputs
    respond_with outputs, represent_with: Api::V1::CourseEventsRepresenter
  end

  api :GET, '/courses/:course_id/practice', 'TODO get rid of this documentation'
  description 'TODO somehow get rid of this API documentation, not desired'
  def practice
    request.post? ? practice_post : practice_get
  end

  api :POST, '/courses/:course_id/practice(/role/:role_id)', 'Starts a new practice widget'
  description 'TBD'
  def practice_post
    entity_task = Domain::ResetPracticeWidget[role: get_practice_role, condition: :fake]
    respond_with entity_task.task, represent_with: Api::V1::TaskRepresenter, location: nil
  end

  api :GET, '/courses/:course_id/practice(/role/:role_id)', 'Gets the most recent practice widget'
  def practice_get
    task = Domain::GetPracticeWidget.call(role: get_practice_role).outputs.task

    task.nil? ?
      head(:not_found) :
      respond_with(task.task, represent_with: Api::V1::TaskRepresenter)
  end

  protected

  def get_practice_role
    potential_roles = Domain::GetUserCourseRoles.call(course: Entity::Course.find(params[:id]),
                                                      user: current_human_user.entity_user,
                                                      types: [:student]).outputs.roles

    raise(SecurityTransgression, "The caller is not a student in this course") if potential_roles.empty?

    practice_role = nil

    if params[:role_id]
      practice_role = Entity::Role.find(params[:role_id])
      raise(SecurityTransgression, "The caller does not have the specified role") unless potential_roles.include?(practice_role)
    else
      raise(IllegalState, "The role must be specified because there is more than one student role available") if potential_roles.size > 1
      practice_role = potential_roles.first
    end

    practice_role
  end

end
