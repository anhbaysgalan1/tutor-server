class CreateOrClaimCourse

  lev_routine express_output: :course

  uses_routine CreateCourse, as: :create_course,
               translations: { outputs: { type: :verbatim } }


  uses_routine CourseProfile::ClaimPreviewCourse,  as: :claim_preview_course,
               translations: { outputs: { type: :verbatim } }

  uses_routine AddUserAsCourseTeacher, as: :add_user_as_teacher,
               translations: { outputs: { type: :verbatim } }

  def exec(attributes)
    user = attributes[:teacher]

    if attributes[:is_preview]
      run(:claim_preview_course, {
            name: attributes[:name],
            catalog_offering: attributes[:catalog_offering]
      })
    else
      run(:create_course, attributes.except(:teacher).merge(is_test: !!user.is_test))
    end

    if errors.none?
      run(:add_user_as_teacher, course: outputs.course, user: user)

      TrackTutorOnboardingEvent.perform_later(
        event: (outputs.course.is_preview? ? 'created_preview_course' : 'created_real_course'),
        user: user,
        data: { course_id: outputs.course.id }
      )
    end
  end


end
