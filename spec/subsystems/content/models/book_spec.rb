require 'rails_helper'

RSpec.describe Content::Models::Book, type: :model do
  subject(:book) { FactoryGirl.create :content_book }

  it { is_expected.to belong_to(:ecosystem) }

  it { is_expected.to have_many(:chapters).dependent(:destroy) }
  it { is_expected.to have_many(:pages) }
  it { is_expected.to have_many(:exercises) }

  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_presence_of(:uuid) }
  it { is_expected.to validate_presence_of(:version) }

  it 'can create a manifest hash' do
    expect(book.manifest_hash).to eq(
      {
        archive_url: book.archive_url,
        cnx_id: book.cnx_id,
        reading_features: {
          reading_split_css: [],
          video_split_css: [],
          interactive_split_css: [],
          required_exercise_css: [],
          optional_exercise_css: [],
          discard_css: []
        },
        exercise_ids: book.exercises.map(&:uid).sort
      }
    )
  end
end
