class CreateContractsAndEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :contracts do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }, index: false
      t.string :title, limit: 160, null: false
      t.string :counterparty, limit: 160, null: false
      t.date :ends_on, null: false
      t.integer :notice_days, null: false
      t.date :notice_due_on, null: false
      t.integer :schedule_revision, null: false, default: 1
      t.string :decision
      t.datetime :decided_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps

      t.index [ :owner_id, :notice_due_on, :id ]
      t.index [ :notice_due_on, :id ], where: "decision IS NULL", name: "index_contracts_on_open_notice_due_on"
      t.check_constraint "notice_days BETWEEN 0 AND 365", name: "contracts_notice_period"
      t.check_constraint "notice_due_on = ends_on - notice_days AND notice_due_on >= DATE '0001-01-01' AND ends_on <= DATE '9999-12-31'", name: "contracts_notice_due_on"
      t.check_constraint "schedule_revision > 0", name: "contracts_schedule_revision"
      t.check_constraint "lock_version >= 0", name: "contracts_lock_version"
      t.check_constraint <<~SQL.squish, name: "contracts_decision_state"
        (decision IS NULL AND decided_at IS NULL) OR
        (decision IS NOT NULL AND decision IN ('renew', 'do_not_renew') AND decided_at IS NOT NULL)
      SQL
    end

    create_table :contract_events do |t|
      t.references :contract, null: false, foreign_key: true, index: false
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :event_type, null: false
      t.jsonb :payload, null: false
      t.datetime :created_at, null: false

      t.index [ :contract_id, :id ]
      t.check_constraint "event_type IN ('contract_created', 'contract_updated', 'decision_recorded')", name: "contract_events_type"
      t.check_constraint "jsonb_typeof(payload) = 'object'", name: "contract_events_payload"
    end
  end
end
