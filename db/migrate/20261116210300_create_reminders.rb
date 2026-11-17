class CreateReminders < ActiveRecord::Migration[8.1]
  def change
    create_table :reminders do |t|
      t.references :contract, null: false, foreign_key: true, index: false
      t.integer :schedule_revision, null: false
      t.datetime :created_at, null: false

      t.index [ :contract_id, :schedule_revision ], unique: true
      t.check_constraint "schedule_revision > 0", name: "reminders_schedule_revision"
    end
  end
end
