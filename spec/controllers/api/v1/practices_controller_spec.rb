require 'rails_helper'
require 'vcr_helper'
require 'database_cleaner'

RSpec.describe Api::V1::PracticesController, api: true, version: :v1, speed: :slow do
  let(:user_1)         { FactoryBot.create(:user) }
  let(:user_1_token)   { FactoryBot.create :doorkeeper_access_token, resource_owner_id: user_1.id }

  let(:user_2)         { FactoryBot.create(:user) }
  let(:user_2_token)   { FactoryBot.create :doorkeeper_access_token, resource_owner_id: user_2.id }

  let(:userless_token) { FactoryBot.create :doorkeeper_access_token }

  let(:course)         { FactoryBot.create :course_profile_course, :without_ecosystem }
  let(:period)         { FactoryBot.create :course_membership_period, course: course }

  let(:page)           { FactoryBot.create :content_page }

  let!(:exercise_1)    { FactoryBot.create :content_exercise, page: page }
  let!(:exercise_2)    { FactoryBot.create :content_exercise, page: page }
  let!(:exercise_3)    { FactoryBot.create :content_exercise, page: page }
  let!(:exercise_4)    { FactoryBot.create :content_exercise, page: page }
  let!(:exercise_5)    { FactoryBot.create :content_exercise, page: page }

  let!(:ecosystem)     do
    ecosystem_strategy = ::Content::Strategies::Direct::Ecosystem.new(page.ecosystem)
    ::Content::Ecosystem.new(strategy: ecosystem_strategy).tap do |ecosystem|
      AddEcosystemToCourse[course: course, ecosystem: ecosystem]
    end
  end

  let!(:role)          { AddUserAsPeriodStudent[period: period, user: user_1] }

  before(:each)        do
    Content::Routines::PopulateExercisePools[book: page.book]

    OpenStax::Biglearn::Api.create_ecosystem(ecosystem: ecosystem)
  end

  context 'POST #create_specific' do
    it 'returns the practice task data' do
      api_post :create_specific,
               user_1_token,
               parameters: { id: course.id, role_id: role.id },
               raw_post_data: { page_ids: [page.id.to_s] }.to_json

      hash = response.body_as_hash
      task = Tasks::Models::Task.last

      expect(hash).to include(
        id: task.id.to_s,
        is_shared: false,
        title: 'Practice',
        type: 'page_practice',
        steps: have(5).items
      )
    end

    it 'returns exercise URLs' do
      api_post :create_specific,
               user_1_token,
               parameters: { id: course.id, role_id: role.id },
               raw_post_data: { page_ids: [page.id.to_s] }.to_json

      hash = response.body_as_hash

      step_urls = Set.new(hash[:steps].map { |s| s[:content_url] })
      exercises = [exercise_1, exercise_2, exercise_3, exercise_4, exercise_5]
      exercise_urls = Set.new(exercises.map(&:url))

      expect(step_urls).to eq exercise_urls
    end

    it 'must be called by a user who belongs to the course' do
      expect{
        api_post :create_specific,
                 user_2_token,
                 parameters: { id: course.id, role_id: role.id },
                 raw_post_data: { page_ids: [page.id.to_s] }.to_json
      }.to raise_error(SecurityTransgression)
    end

    it 'returns error when no exercises can be scrounged' do
      AddUserAsPeriodStudent.call(period: period, user: user_1)

      expect(OpenStax::Biglearn::Api).to receive(:fetch_assignment_pes).and_return(
        {
          accepted: true,
          exercises: [],
          spy_info: {}
        }
      )

      api_post :create_specific,
               user_1_token,
               parameters: { id: course.id, role_id: role.id },
               raw_post_data: { page_ids: [page.id.to_s] }.to_json

      expect(response).to have_http_status(422)
    end

    it "422's if needs to pay" do
      make_payment_required_and_expect_422(course: course, user: user_1) {
        api_post :create_specific,
                 user_1_token,
                 parameters: { id: course.id, role_id: role.id },
                 raw_post_data: { page_ids: [page.id.to_s] }.to_json
      }
    end
  end

  context 'POST #create_worst' do
    it 'returns the practice task data' do
      api_post :create_worst, user_1_token, parameters: { id: course.id, role_id: role.id }

      hash = response.body_as_hash
      task = Tasks::Models::Task.last

      expect(hash).to include(
        id: task.id.to_s,
        is_shared: false,
        title: 'Practice',
        type: 'practice_worst_topics',
        steps: have(5).items
      )
    end

    it 'returns exercise URLs' do
      api_post :create_worst, user_1_token, parameters: { id: course.id, role_id: role.id }

      hash = response.body_as_hash

      step_urls = Set.new(hash[:steps].map { |s| s[:content_url] })
      exercises = [exercise_1, exercise_2, exercise_3, exercise_4, exercise_5]
      exercise_urls = Set.new(exercises.map(&:url))

      expect(step_urls).to eq exercise_urls
    end

    it 'must be called by a user who belongs to the course' do
      expect do
        api_post :create_worst, user_2_token, parameters: { id: course.id, role_id: role.id }
      end.to raise_error(SecurityTransgression)
    end

    it 'returns error when no exercises can be scrounged' do
      AddUserAsPeriodStudent.call(period: period, user: user_1)

      expect(OpenStax::Biglearn::Api).to receive(:fetch_practice_worst_areas_exercises).and_return(
        {
          accepted: true,
          exercises: [],
          spy_info: {}
        }
      )

      api_post :create_worst, user_1_token, parameters: { id: course.id, role_id: role.id }

      expect(response).to have_http_status(422)
    end


    it "422's if needs to pay" do
      make_payment_required_and_expect_422(course: course, user: user_1) {
        api_post :create_worst,
                 user_1_token,
                 parameters: { id: course.id, role_id: role.id }
      }
    end
  end

  context 'GET #show' do
    it 'returns nothing when practice widget not yet set' do
      AddUserAsPeriodStudent.call(period: period, user: user_1)
      api_get :show, user_1_token, parameters: { id: course.id, role_id: Entity::Role.last.id }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns a practice widget' do
      AddUserAsPeriodStudent.call(period: period, user: user_1)
      role = Entity::Role.last

      CreatePracticeSpecificTopicsTask[course: course, role: role, page_ids: [page.id]]
      CreatePracticeSpecificTopicsTask[course: course, role: role, page_ids: [page.id]]

      api_get :show, user_1_token, parameters: { id: course.id, role_id: role.id }

      expect(response).to have_http_status(:success)

      expect(response.body_as_hash).to(
        include(id: be_kind_of(String), title: 'Practice', steps: have(5).items)
      )
    end

    it "422's if needs to pay" do
      AddUserAsPeriodStudent.call(period: period, user: user_1)
      make_payment_required_and_expect_422(course: course, user: user_1) {
        api_get :show, user_1_token, parameters: { id: course.id,
                                                   role_id: Entity::Role.last.id }
      }
    end

    it 'can be called by a teacher using a student role' do
      AddUserAsCourseTeacher.call(course: course, user: user_1)
      student_role = AddUserAsPeriodStudent[period: period, user: user_2]
      CreatePracticeSpecificTopicsTask[course: course, role: student_role, page_ids: [page.id]]

      api_get :show, user_1_token, parameters: { id: course.id, role_id: student_role.id }

      expect(response).to have_http_status(:success)
    end

    it 'raises SecurityTransgression if user is anonymous or not in the course as a student' do
      expect {
        api_get :show, nil, parameters: { id: course.id }
      }.to raise_error(SecurityTransgression)

      expect {
        api_get :show, user_1_token, parameters: { id: course.id }
      }.to raise_error(SecurityTransgression)

      AddUserAsCourseTeacher.call(course: course, user: user_1)

      expect {
        api_get :show, user_1_token, parameters: { id: course.id }
      }.to raise_error(SecurityTransgression)
    end
  end
end
