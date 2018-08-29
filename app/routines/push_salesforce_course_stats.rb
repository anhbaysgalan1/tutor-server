class PushSalesforceCourseStats

  # This code works hard to catch exceptions when pushing stats for courses, because
  # we don't want an issue with one course to kill stats for all remaining courses.
  # When an exception (or other issue) is encountered, we call `error!` which logs
  # the problem for logging and email notification, then stops the processing of
  # the current course via `throw`/`catch` calls (to avoid always remembering to
  # `return` after `error!` and to avoid using exceptions which we catch all of)

  # shortcuts
  TC = OpenStax::Salesforce::Remote::TutorCourse
  IA = OpenStax::Salesforce::Remote::IndividualAdoption

  def self.call(allow_error_email:)
    new(allow_error_email: allow_error_email).call
  end

  def initialize(allow_error_email:)
    @allow_error_email = allow_error_email
    @errors = []
    @skips = []
    @num_updates = 0
    @num_errors = 0
    @num_skips = 0
  end

  def call
    log { "Starting..." }

    applicable_courses.each do |course|
      catch(:go_to_next_course) do
        call_for_course(course)
      end
    end

    notify_errors
    notify_skips

    counts = {
      num_courses: applicable_courses.size,
      num_updates: @num_updates,
      num_errors: @num_errors,
      num_skips: @num_skips
    }

    log {
      "Processed #{counts[:num_courses]} course(s); wrote stats for #{counts[:num_updates]} of " +
      "these; skipped #{counts[:num_skips]}; #{counts[:num_errors]} course(s) ran into an error."
    }

    counts
  end

  def call_for_course(course)
    begin
      skip!(message: "No teachers", course: course) if teachers(course).length == 0

      attached_record = courses_to_attached_records[course]
      os_tutor_course = attached_record.try(:salesforce_object)

      if os_tutor_course.nil?
        if attached_record.present?
          # The SF record used to exist but no longer does, so detach the record.
          log { "TutorCourse #{attached_record.salesforce_id} used to exist for course #{course.id} "
                "but is no longer in SF.  Tutor will forget about it." }
          attached_record.destroy!
        end

        os_tutor_course = find_or_create_os_tutor_course(course)

        Salesforce::AttachRecord[record: os_tutor_course, to: course]
      end

      push_stats(course, os_tutor_course)
    rescue Exception => ee
      error!(exception: ee, course: course)
    end
  end

  def find_or_create_os_tutor_course(course)
    tc = find_os_tutor_course_by_course_uuid(course)
    return tc if tc.present?

    ia = find_or_create_individual_adoption(course)
    create_os_tutor_course(course, ia)
  end

  def find_os_tutor_course_by_course_uuid(course)
    # First, see if an TC exists for this course.  There can be at most 1 because
    # salesforce requires the UUID field to be unique
    TC.where(course_uuid: course.uuid).to_a.first
  end

  def find_or_create_individual_adoption(course)
    offering = course.offering
    error!(message: "No offering for course", course: course) if offering.nil?

    book_name = offering.salesforce_book_name
    sf_contact_id = best_sf_contact_id_for_course(course)

    individual_adoption_criteria = {
      contact_id: sf_contact_id,
      book_name: book_name,
      school_year: salesforce_school_year_for_course(course)
    }

    candidate_individual_adoptions = OpenStax::Salesforce::Remote::IndividualAdoption
                                       .where(individual_adoption_criteria)
                                       .to_a

    if candidate_individual_adoptions.size > 1
      error!(message: "Too many IndividualAdoptions matching #{individual_adoption_criteria}",
             course: course)
    end

    return candidate_individual_adoptions.first if candidate_individual_adoptions.one?

    sf_contact = OpenStax::Salesforce::Remote::Contact.where(id: sf_contact_id).first

    individual_adoption_options = {
      contact_id: sf_contact_id,
      book_id: book_names_to_sf_ids[book_name],
      school_id: sf_contact.school_id,
      adoption_level: "Confirmed Adoption Won",
      source: "Tutor Signup",
      description: Time.now.in_time_zone('Central Time (US & Canada)').to_date.iso8601 + ", " +
                   (OpenStax::Salesforce::User.first.try(:name) || 'Unknown') + ", Created by Tutor"
    }

    IA.new(individual_adoption_options).tap do |ia|
      if !ia.save
        error!(message: "Could not make new IndividualAdoption for inputs " \
                        "#{individual_adoption_options}; errors: " \
                        "#{ia.errors.full_messages.join(', ')}",
               course: course)
      end
    end
  end

  def create_os_tutor_course(course, individual_adoption)
    arguments = {
      individual_adoption_id: individual_adoption.id,
      product: course.is_concept_coach ? "Concept Coach" : "Tutor",
      term: course.term.capitalize,
      contact_id: best_sf_contact_id_for_course(course),
      base_year: base_year_for_course(course)
    }

    TC.new(arguments).tap do |tc|
      if !tc.save
        error!(message: "Could not make new Tcncillary for inputs #{arguments}; " \
                        "errors: #{tc.errors.full_messages.join(', ')}",
               course: course)
      end

      # Values in the TC that are derived from other places in SF, e.g. `TermYear`,
      # cannot be set when creating the record.  Instead of manually setting them
      # here, just reload the object from SF so that we know any derived fields are
      # populated.
      tc.reload
    end
  end

  def salesforce_school_year_for_course(course)
    base_year = base_year_for_course(course)
    "#{base_year} - #{(base_year + 1).to_s[2..3]}"
  end

  def base_year_for_course(course)
    case course.term
    when 'fall'
      course.year
    when 'spring', 'summer', 'winter'
      course.year - 1
    else
      raise "Unhandled course term #{course.term}"
    end
  end

  def push_stats(course, os_tutor_course)
    error!(message: 'TutorCourse nil in `push_stats`', course: course) if os_tutor_course.nil?

    os_tutor_course.error = nil

    begin
      periods = course.periods.without_deleted

      os_tutor_course.course_id = course.id
      os_tutor_course.course_uuid = course.uuid
      os_tutor_course.course_name = course.name
      os_tutor_course.created_at = course.created_at.iso8601
      os_tutor_course.teacher_join_url = UrlGenerator.teach_course_url(course.teach_token)

      os_tutor_course.reset_stats

      students = periods.flat_map do |period|
        period.students.preload({role: {taskings: :task}})
      end

      students.each do |student|
        os_tutor_course.num_students += 1
        os_tutor_course.num_students_paid += 1 if student.is_paid
        os_tutor_course.num_students_comped += 1 if student.is_comped
        os_tutor_course.num_students_refunded += 1 if student.first_paid_at.present? && !student.is_paid
        os_tutor_course.num_students_dropped += 1 if student.dropped?

        num_steps_completed = student.role.taskings.map{ |tasking|
          tasking.task.completed_steps_count
        }.sum

        os_tutor_course.num_students_with_work += 1 if num_steps_completed >= 10
      end

      os_tutor_course.num_teachers = course.teachers.length
      os_tutor_course.num_sections = periods.length

      os_tutor_course.estimated_enrollment = course.estimated_student_count

      os_tutor_course.status = TC::STATUS_APPROVED
      os_tutor_course.product = course.is_concept_coach ? "Concept Coach" : "Tutor"

      os_tutor_course.course_start_date = course.term_year.starts_at.to_date.iso8601
      os_tutor_course.term = course.term.capitalize
      os_tutor_course.base_year = base_year_for_course(course)

      os_tutor_course.does_cost = course.does_cost

      os_tutor_course.latest_adoption_decision = course.latest_adoption_decision
      os_tutor_course.campaign_member_id = course.creator_campaign_member_id
    rescue Exception => ee
      # Add the error to the TC and `error!` but non fatally so the error can get saved
      # to the TC
      os_tutor_course.error = "Unable to update stats: #{ee.message}"
      error!(message: 'Unable to update stats', exception: ee, course: course, non_fatal: true)
    end

    begin
      return if !os_tutor_course.changed?

      if os_tutor_course.save
        @num_updates += 1
      else
        error!(message: os_tutor_course.errors.full_messages.join(', '), course: course)
      end
    rescue Exception => ee
      error!(message: 'TC save error', exception: ee, course: course)
    end
  end

  def teachers(course)
    course.teachers.order(:created_at)
  end

  def best_sf_contact_id_for_course(course)
    @cache ||= {}
    (
      @cache[course.uuid] ||=
        teachers(course).order{created_at.asc}
                        .map{|tt| tt.role.role_user.profile.account.salesforce_contact_id}
                        .compact
                        .first
    ).tap do |contact_id|
      error!(message: "No teachers have a SF contact ID", course: course) if contact_id.nil?
    end
  end

  def applicable_courses
    # Don't update courses that have ended
    @courses ||= CourseProfile::Models::Course
                   .not_ended
                   .where(is_test: false)
                   .where(is_excluded_from_salesforce: false)
                   .where(term: CourseProfile::Models::Course.terms.slice(*%w(spring summer fall)).values)
                   .where(is_preview: false)
                   .to_a
  end

  def courses_to_attached_records
    @courses_to_attached_records ||= begin
      ars = Salesforce::AttachedRecord
              .preload(:salesforce_objects)
              .reject(&:deleted?)
              .select{|ar| ar.attached_to_class_name == "CourseProfile::Models::Course"}
      ars.map{|ar| [ar.attached_to, ar]}.to_h
    end
  end

  def book_names_to_sf_ids
    @book_names_to_sf_ids ||= begin
      all_books = OpenStax::Salesforce::Remote::Book.all
      all_books.each_with_object({}) do |book, hash|
        hash[book.name] = book.id
      end
    end
  end

  def log(&block)
    Rails.logger.info { "[#{self.class.name}] #{block.call}" }
  end

  def error!(exception: nil, message: nil, course: nil, non_fatal: false)
    begin
      error = {}

      error[:message] = message || exception.try(:message)
      error[:exception] = {
        class: exception.class.name,
        message: exception.message,
        first_backtrace_line: exception.backtrace.try(:first)
      } if exception.present?
      error[:course] = course.id if course.present?

      @errors.push(error)

      @num_errors += 1
    ensure
      throw :go_to_next_course unless non_fatal
    end
  end

  def skip!(message: nil, course: nil)
    begin
      skip = {}

      skip[:message] = message if message.present?
      skip[:course] = course.id if course.present?

      @skips.push(skip) if skip.present?

      @num_skips += 1
    ensure
      throw :go_to_next_course
    end
  end

  def notify_errors
    return if @errors.empty?

    Rails.logger.warn { "[#{self.class.name}] Errors: " + @errors.inspect }

    if @allow_error_email && is_real_production?
      DevMailer.inspect_object(
        object: @errors,
        subject: "#{self.class.name} errors",
        to: Rails.application.secrets.salesforce['mail_recipients']
      ).deliver_later
    end
  end

  def notify_skips
    log { "Skips: " + @skips.inspect } unless @skips.empty?
  end

  def is_real_production?
    Rails.application.secrets.environment_name == "prodtutor"
  end

end
