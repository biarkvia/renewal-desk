module Renewals
  module ContractMapper
    def self.load(record)
      Contract.new(
        id: record.id,
        title: record.title,
        counterparty: record.counterparty,
        ends_on: record.ends_on,
        notice_days: record.notice_days,
        schedule_revision: record.schedule_revision,
        decision: record.decision,
        decided_at: record.decided_at&.to_time
      )
    end

    def self.attributes(contract)
      {
        title: contract.title,
        counterparty: contract.counterparty,
        ends_on: contract.ends_on,
        notice_days: contract.notice_days,
        notice_due_on: contract.notice_due_on,
        schedule_revision: contract.schedule_revision,
        decision: contract.decision,
        decided_at: contract.decided_at
      }
    end
  end
end
