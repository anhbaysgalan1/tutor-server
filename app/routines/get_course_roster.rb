class GetCourseRoster
  lev_routine express_output: :roster

  protected

  def exec(course:)
    students = course.students.with_deleted.includes(:enrollments, role: { profile: :account })

    outputs.roster = {
      teach_url: UrlGenerator.new.teach_course_url(course.teach_token,"DO_NOT_GIVE_TO_STUDENTS"),
      students: students.map do |student|
        Hashie::Mash.new({
          id: student.id,
          first_name: student.first_name,
          last_name: student.last_name,
          name: student.name,
          course_membership_period_id: student.course_membership_period_id,
          entity_role_id: student.entity_role_id,
          username: student.username,
          deidentifier: student.deidentifier,
          active?: !student.deleted?
        })
      end
    }
  end
end
