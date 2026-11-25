class CreateScheduledTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :scheduled_tasks, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :title
      t.string :action_type, null: false
      t.string :target_type
      t.bigint :target_id
      t.json :payload
      t.datetime :scheduled_at, null: false
      t.integer :status, null: false, default: 0
      t.datetime :executed_at
      t.text :result_message
      t.text :error_message
      t.bigint :created_by_id

      t.timestamps
    end

    add_index :scheduled_tasks, [:status, :scheduled_at]
    add_index :scheduled_tasks, :scheduled_at
    add_index :scheduled_tasks, :created_by_id
    add_index :scheduled_tasks, [:target_type, :target_id]
  end
end
