require 'rails_helper'

RSpec.describe Section, :type => :model do
  it { is_expected.to belong_to(:course) }

  it { is_expected.to have_many(:students).dependent(:nullify) }
  it { is_expected.to have_many(:tasking_plans).dependent(:destroy) }

  it { is_expected.to validate_presence_of(:course) }
  it { is_expected.to validate_presence_of(:name) }

  it 'enforces name uniqueness within a section' do
    section1 = FactoryGirl.create(:section)
    section2 = FactoryGirl.create(:section, course_id: section1.course_id)
    section2.name = section1.name
    expect(section2).to_not be_valid
  end
end
