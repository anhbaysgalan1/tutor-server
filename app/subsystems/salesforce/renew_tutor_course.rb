module Salesforce
  class RenewTutorCourse

    # `based_on` is an `TutorCourse`
    def self.call(based_on:, renew_for_term_year:)

      # Would be nice to have preloaded opportunity, but have had problems making it work
      based_on_opportunity = based_on.opportunity

      # We want to hang a new TC off of a similar opportunity for the next TermYear
      target_opportunity_criteria = {
        contact_id: based_on_opportunity.contact_id,
        book_name: based_on_opportunity.book_name,
        term_year: renew_for_term_year.to_s,
        new: true
      }

      target_opportunities = OpenStax::Salesforce::Remote::Opportunity.where(target_opportunity_criteria).to_a

      if target_opportunities.size > 1
        raise TutorCourseRenewalError, "Too many opportunities matching #{target_opportunity_criteria}"
      elsif target_opportunities.size == 0
        raise TutorCourseRenewalError, "No opportunities matching #{target_opportunity_criteria}"
      end

      target_opportunity = target_opportunities.first

      tutor_course_attributes = {
        opportunity_id: target_opportunity.id,
        product: based_on.product
      }

      existing_tutor_course = OpenStax::Salesforce::Remote::TutorCourse.where(tutor_course_attributes).first
      return existing_tutor_course if existing_tutor_course.present?

      new_tutor_course = OpenStax::Salesforce::Remote::TutorCourse.new(
        tutor_course_attributes.merge(
          course_id: based_on.course_id,
          status: OpenStax::Salesforce::Remote::TutorCourse::STATUS_APPROVED,
          error: nil,
          teacher_join_url: based_on.teacher_join_url
        )
      )

      if !new_tutor_course.save
        raise TutorCourseRenewalError,
              "Could not save renewed TC: " \
              "#{new_tutor_course.errors.full_messages.join(', ')}"
      end

      # Values in the TC that are derived from other places in SF, e.g. `TermYear`,
      # cannot be set when creating the record above.  Instead of manually setting them
      # here, just reload the object from SF so that we know any derived fields are
      # populated.
      new_tutor_course.reload
    end
  end
end
