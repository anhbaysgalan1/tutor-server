require 'rails_helper'

RSpec.describe Api::V1::StudentRepresenter, type: :representer do
  let(:user)    { FactoryGirl.create(:user) }
  let(:period)  { FactoryGirl.create(:course_membership_period) }
  let(:student) { AddUserAsPeriodStudent.call(period: period, user: user).outputs.student }

  it 'represents a student' do
    representation = Api::V1::StudentRepresenter.new(student).as_json
    expect(representation).to include(
      'id' => student.id.to_s,
      'period_id' => period.id.to_s,
      'role_id' => student.role.id.to_s,
      'first_name' => student.first_name,
      'last_name' => student.last_name,
      'name' => student.name,
      'is_active' => !student.deleted?,
      'is_paid' => false,
      'is_comped' => false,
      'payment_due_at' => be_kind_of(String)
    )
  end
end
