Entity::Models::Task.has_many :taskings, subsystem: :tasks, foreign_key: :entity_task_id
Entity::Models::Task.has_many :legacy_task_maps, subsystem: :tasks, foreign_key: :entity_task_id