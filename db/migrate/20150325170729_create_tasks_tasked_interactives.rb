class CreateTasksTaskedInteractives < ActiveRecord::Migration
  def change
    create_table :tasks_tasked_interactives do |t|
      t.string :url, null: false
      t.text :content, null: false
      t.string :title

      t.timestamps null: false
    end
  end
end
