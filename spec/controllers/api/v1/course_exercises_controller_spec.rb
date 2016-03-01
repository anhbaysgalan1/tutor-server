require 'rails_helper'
require 'vcr_helper'
require 'database_cleaner'

RSpec.describe Api::V1::CourseExercisesController, type: :controller, api: true,
                                                   version: :v1, speed: :slow, vcr: VCR_OPTS do

  let!(:user_1)         { FactoryGirl.create(:user) }
  let!(:user_1_token)   { FactoryGirl.create :doorkeeper_access_token,
                                             resource_owner_id: user_1.id }

  let!(:user_2)         { FactoryGirl.create(:user) }
  let!(:user_2_token)   { FactoryGirl.create :doorkeeper_access_token,
                                             resource_owner_id: user_2.id }

  let!(:userless_token) { FactoryGirl.create :doorkeeper_access_token }

  let!(:course)         { CreateCourse[name: 'Physics 101'] }
  let!(:period)         { CreatePeriod[course: course] }

  context 'with a real book' do
    before(:all) do
      DatabaseCleaner.start

      VCR.use_cassette("Api_V1_CourseExercisesController/with_book", VCR_OPTS) do
        @ecosystem = FetchAndImportBookAndCreateEcosystem[
          book_cnx_id: '93e2b09d-261c-4007-a987-0b3062fe154b'
        ]
      end
    end

    before(:each) do
      CourseContent::AddEcosystemToCourse.call(course: course, ecosystem: @ecosystem)
      AddUserAsCourseTeacher.call(course: course, user: user_1)
    end

    after(:all) do
      DatabaseCleaner.clean
    end

    describe "#index" do
      it 'raises SecurityTransgression if user is anonymous or not a teacher' do
        page_ids = Content::Models::Page.all.map(&:id)

        expect {
          api_get :index, nil, parameters: { course_id: course.id, page_ids: page_ids }
        }.to raise_error(SecurityTransgression)

        expect {
          api_get :index, user_2_token, parameters: { course_id: course.id, page_ids: page_ids }
        }.to raise_error(SecurityTransgression)
      end

      it "should return all exercises if page_ids is ommitted" do
        api_get :index, user_1_token, parameters: { course_id: course.id }

        expect(response).to have_http_status(:success)
        expect(response.body_as_hash[:total_count]).to eq(@ecosystem.exercises.size)
      end

      it "should return an empty result if page_ids is empty" do
        api_get :index, user_1_token, parameters: { course_id: course.id, page_ids: [] }

        expect(response).to have_http_status(:success)
        expect(response.body_as_hash).to eq({total_count: 0, items: []})
      end

      it "works for teachers in the course" do
        page_ids = Content::Models::Page.all.map(&:id)
        api_get :index, user_1_token, parameters: { course_id: course.id, page_ids: page_ids}

        expect(response).to have_http_status(:success)
        hash = response.body_as_hash
        expect(hash[:total_count]).to eq(215)
        page_los = Content::Models::Page.all.map(&:los).flatten.collect(&:value)
        hash[:items].each do |item|
          expect(item[:pool_types]).not_to be_empty
          wrapper = OpenStax::Exercises::V1::Exercise.new(content: item[:content].to_json)
          item_los = wrapper.los
          expect(item_los).not_to be_empty
          item_los.each do |item_lo|
            expect(page_los).to include(item_lo)
          end
        end
      end

      it "returns only exercises in certain pools if pool_types are given" do
        page_ids = Content::Models::Page.all.map(&:id)
        api_get :index, user_1_token, parameters: {
          course_id: course.id, page_ids: page_ids, pool_types: 'homework_core'
        }

        expect(response).to have_http_status(:success)
        hash = response.body_as_hash
        expect(hash[:total_count]).to eq(70)
        page_los = Content::Models::Page.all.map(&:los).flatten.collect(&:value)
        hash[:items].each do |item|
          expect(item[:pool_types]).to eq ['homework_core']
          wrapper = OpenStax::Exercises::V1::Exercise.new(content: item[:content].to_json)
          item_los = wrapper.los
          expect(item_los).not_to be_empty
          item_los.each do |item_lo|
            expect(page_los).to include(item_lo)
          end
        end
      end

      it "returns exercise exclusion information" do
        api_get :index, user_1_token, parameters: { course_id: course.id }

        expect(response).to have_http_status(:success)
        hash = response.body_as_hash
        hash[:items].each{ |item| expect(item[:is_excluded]).to eq false }
      end
    end
  end

end
