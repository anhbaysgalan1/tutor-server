class CreateContentEcosystems < ActiveRecord::Migration
  def change
    create_table :content_ecosystems do |t|
      t.timestamps null: false
    end
  end
end
