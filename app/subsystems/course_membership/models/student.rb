class CourseMembership::Models::Student < Tutor::SubSystems::BaseModel
  acts_as_paranoid

  belongs_to :course, subsystem: :entity
  belongs_to :role, subsystem: :entity

  has_many :enrollments, -> { with_deleted }, dependent: :destroy

  validates :course, presence: true
  validates :role, presence: true, uniqueness: true
  validates :deidentifier, uniqueness: true
  validates :student_identifier, uniqueness: { scope: :course, allow_nil: true }

  unique_token :deidentifier, mode: { hex: { length: 4 } }

  delegate :username, :first_name, :last_name, :full_name, :name, to: :role
  delegate :period, :course_membership_period_id, to: :latest_enrollment

  def latest_enrollment
    enrollments.last
  end
end
