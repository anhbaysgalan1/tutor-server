require 'rails_helper'

RSpec.describe CollectImportJobsData, type: :routine do
  context "when there are any" do
    let!(:school) { FactoryGirl.build :school_district_school }
    let!(:course_profile) { FactoryGirl.create :course_profile_profile, school: school, name: "Learn how to learn" }

    before(:each) do
      Jobba.all.delete_all!
      expect(Jobba.all.count).to eq 0
    end

    context "incomplete (queued) jobs" do
      before(:each) do
        2.times{
          job = Jobba.create!
          job.save({ course_id: course_profile.entity_course_id, course_ecosystem: "Physics (334f8b61-30eb-4475-8e05-5260a4866b4b@7.42) - 2016-08-10 18:10:50 UTC" })
          Jobba.find!(job.id).queued!
        }
        expect(Jobba.where(state: :incomplete).to_a.count).to eq 2
      end

      let!(:incomplete_jobs) { described_class[state: :incomplete] }

      it "returns the incomplete jobs with their associated data as an array of hashes" do
        expect(incomplete_jobs).to be_a Array
        expect(incomplete_jobs.first).to be_a Hash
      end

      it "returns a hash with the specified keys for each item in the array" do
        job =Jobba.where(state: :incomplete).to_a.last
        expected_result = { id: job.id, state_name: job.state.name, course_ecosystem: job.data["course_ecosystem"],
                            course_profile_profile_name: course_profile.name }
        expect(incomplete_jobs.last).to match expected_result
      end
    end

    context "failed jobs" do
      before(:each) do
        2.times{
          job = Jobba.create!
          job.save({ course_id: course_profile.entity_course_id, course_ecosystem: "Physics (334f8b61-30eb-4475-8e05-5260a4866b4b@7.42) - 2016-08-10 18:10:50 UTC" })
          Jobba.find!(job.id).failed!
        }
        expect(Jobba.where(state: :failed).to_a.count).to eq 2
      end
      let!(:failed_jobs) { described_class[state: :failed] }

      it "returns the failed jobs with their associated data as an array of hashes" do
        expect(failed_jobs.count).to eq 2
        expect(failed_jobs).to be_a Array
        expect(failed_jobs.first).to be_a Hash
      end

      it "returns a hash with the specified keys for each item in the array" do
        job = Jobba.where(state: :failed).to_a.last
        expected_result = { id: job.id, state_name: job.state.name, course_ecosystem: job.data["course_ecosystem"],
                            course_profile_profile_name: course_profile.name }
        expect(failed_jobs.last).to match expected_result
      end
    end
  end

  context "when there are no results" do
    before(:each) do
      Jobba.all.delete_all!
      expect(Jobba.all.count).to eq 0
    end

    it "doesn't blow up" do
      expect{described_class[state: :incomplete]}.to_not raise_error
    end

    it "returns an empty array" do
      result = described_class[state: :incomplete]
      expect(result).to eq []
    end
  end

  context "when the results have no data hash" do
    before(:each) do
      Jobba.all.delete_all!
      expect(Jobba.all.count).to eq 0

      2.times {
        job = Jobba.create!
        Jobba.find!(job.id).queued!
      }
      expect(Jobba.where(state: :queued).to_a.count).to eq 2
    end

    it "doesn't blow up" do
      expect{described_class[state: :queued]}.to_not raise_error
    end

    it "returns an empty array" do
      result = described_class[state: :queued]
      expect(result).to eq []
    end
  end
end
