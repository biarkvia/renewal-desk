module Renewals
  module IssueReminders
    def self.call(today:)
      cutoff = today + NoticeSchedule::REMINDER_LEAD_DAYS
      candidates = ContractRecord.where(decision: nil, notice_due_on: ..cutoff).where(<<~SQL)
        NOT EXISTS (
          SELECT 1 FROM reminders
          WHERE reminders.contract_id = contracts.id
            AND reminders.schedule_revision = contracts.schedule_revision
        )
      SQL

      candidates.select(:id).find_each(batch_size: 200) do |candidate|
        issue(candidate.id, today: today)
      end
    end

    def self.issue(contract_id, today:)
      ContractRecord.transaction(requires_new: true) do
        record = ContractRecord.lock.find_by(id: contract_id)
        next unless record && ContractMapper.load(record).due_for_reminder?(today: today)

        Reminder.insert(
          { contract_id: record.id, schedule_revision: record.schedule_revision },
          unique_by: :index_reminders_on_contract_id_and_schedule_revision, returning: false
        )
      end
    end
    private_class_method :issue
  end
end
