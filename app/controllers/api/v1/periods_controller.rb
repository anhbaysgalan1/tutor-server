class Api::V1::PeriodsController < Api::V1::ApiController
  before_filter :find_period_and_course

  resource_description do
    api_versions "v1"
    short_description 'Represents course periods in the system'
    description <<-EOS
      Period description to be written...
    EOS
  end

  api :POST, '/courses/:course_id/periods', 'Returns a new course period for given course'
  description <<-EOS
    #{json_schema(Api::V1::PeriodRepresenter, include: :readable)}
  EOS
  def create
    OSU::AccessPolicy.require_action_allowed!(:add_period, current_human_user, @course)
    result = CreatePeriod.call(course: @course, **consumed(Api::V1::PeriodRepresenter))

    if result.errors.any?
      render_api_errors(result.errors)
    else
      respond_with result.outputs.period,
                   represent_with: Api::V1::PeriodRepresenter,
                   location: nil
    end
  end

  api :PATCH, '/periods/:id', 'Returns an updated period for the given course'
  description <<-EOS
    #{json_schema(Api::V1::PeriodRepresenter, include: :readable)}
  EOS
  def update
    OSU::AccessPolicy.require_action_allowed!(:update, current_human_user, @period)

    result = CourseMembership::UpdatePeriod.call(
      period: @period,
      **consumed(Api::V1::PeriodRepresenter)
    )

    if result.errors.any?
      render_api_errors(result.errors)
    else
      respond_with result.outputs.period,
                   represent_with: Api::V1::PeriodRepresenter,
                   location: nil,
                   responder: ResponderWithPutPatchDeleteContent
    end
  end

  api :DELETE, '/periods/:id', 'Deletes a period for authorized teachers'
  description <<-EOS
    #{json_schema(Api::V1::PeriodRepresenter, include: :readable)}
  EOS
  def destroy
    standard_destroy(@period.to_model, Api::V1::PeriodRepresenter)
  end

  private

  def find_period_and_course
    if params[:course_id]
      @course = Entity::Course.find(params[:course_id])
    elsif params[:id]
      @period = CourseMembership::GetPeriod[id: params[:id]]
      @course = @period.course
    end
  end
end
