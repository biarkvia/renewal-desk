module Renewals
  module ContractWriter
    def self.create(owner:, title:, counterparty:, ends_on:, notice_days:)
      contract = Contract.new(title: title, counterparty: counterparty, ends_on: ends_on, notice_days: notice_days)

      ContractRecord.transaction(requires_new: true) do
        details = ContractMapper.attributes(contract)
        record = ContractRecord.create!(owner: owner, **details)
        record.events.create!(actor: owner, event_type: "contract_created", payload: details.except(:decision, :decided_at))
        record
      end
    end

    def self.update(owner:, id:, lock_version:, **details)
      with_current_contract(owner: owner, id: id, lock_version: lock_version) do |record, contract|
        contract.update_details(**details)
        record.assign_attributes(ContractMapper.attributes(contract))

        if record.has_changes_to_save?
          changes = record.changes_to_save.transform_values { |before, after| { from: before, to: after } }
          record.save!
          record.events.create!(actor: owner, event_type: "contract_updated", payload: changes)
        end
      end
    end

    def self.record_decision(owner:, id:, lock_version:, decision:)
      with_current_contract(owner: owner, id: id, lock_version: lock_version) do |record, contract|
        contract.record_decision(decision: decision, decided_at: Time.current.to_time)
        record.update!(decision: contract.decision, decided_at: contract.decided_at)
        record.events.create!(actor: owner, event_type: "decision_recorded", payload: { decision: contract.decision }, created_at: record.decided_at)
      end
    end

    def self.with_current_contract(owner:, id:, lock_version:)
      ContractRecord.transaction(requires_new: true) do
        record = ContractRecord.where(owner: owner).lock.find(id)
        unless record.lock_version.eql?(lock_version)
          raise StaleVersion.new(contract_id: record.id, expected_version: lock_version, current_version: record.lock_version)
        end

        yield record, ContractMapper.load(record)
        record
      end
    end
    private_class_method :with_current_contract
  end
end
