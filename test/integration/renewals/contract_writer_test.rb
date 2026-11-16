require "test_helper"

module Renewals
  class ContractWriterTest < ActiveSupport::TestCase
    setup do
      @owner = users(:owner)
    end

    test "creation persists the schedule and exactly one history event" do
      assert_difference [ "ContractRecord.count", "ContractEvent.count" ], 1 do
        @record = create_contract(title: " Office Internet ")
      end

      record = @record.reload
      assert_equal @owner, record.owner
      assert_equal "Office Internet", record.title
      assert_equal Date.new(2026, 12, 1), record.notice_due_on
      assert_equal 1, record.schedule_revision
      assert_equal 0, record.lock_version
      assert_nil record.decision

      event = record.events.sole
      assert_equal @owner, event.actor
      assert_equal "contract_created", event.event_type
      assert_equal "2026-12-01", event.payload.fetch("notice_due_on")
      assert_predicate event.created_at, :present?
    end

    test "Gregorian dates round-trip through PostgreSQL" do
      day = Date.new(1582, 10, 10, Date::GREGORIAN)
      record = create_contract(ends_on: day, notice_days: 1).reload
      contract = ContractMapper.load(record)

      assert_equal day, contract.ends_on
      assert_equal "1582-10-09", record.notice_due_on.iso8601
      assert_equal record.notice_due_on, contract.notice_due_on
    end

    test "localized details round-trip through the contract and history" do
      record = create_contract(title: " Datová přípojka ".encode(Encoding::UTF_16LE)).reload

      assert_equal "Datová přípojka", record.title
      assert_equal record.title, record.events.sole.payload.fetch("title")
    end

    test "updating the schedule records changed fields and advances the version" do
      record = create_contract
      updated = ContractWriter.update(owner: @owner, id: record.id, lock_version: record.lock_version, notice_days: 31)

      assert_equal Date.new(2026, 11, 30), updated.notice_due_on
      assert_equal 2, updated.schedule_revision
      assert_equal 1, updated.lock_version
      assert_equal %w[contract_created contract_updated], updated.events.map(&:event_type)
      event = updated.events.last
      assert_equal @owner, event.actor
      assert_equal({
        "notice_days" => { "from" => 30, "to" => 31 },
        "notice_due_on" => { "from" => "2026-12-01", "to" => "2026-11-30" },
        "schedule_revision" => { "from" => 1, "to" => 2 }
      }, event.payload)
    end

    test "submitting the same details preserves the version and history" do
      record = create_contract

      assert_no_difference "ContractEvent.count" do
        updated = ContractWriter.update(owner: @owner, id: record.id, lock_version: 0, title: " Office Internet ", notice_days: 30)
        assert_equal record.lock_version, updated.lock_version
        assert_equal record.updated_at, updated.updated_at
      end
    end

    test "recording a decision assigns server time and appends history" do
      record = create_contract
      now = Time.utc(2026, 12, 2, 10)

      travel_to(now) do
        ContractWriter.record_decision(owner: @owner, id: record.id, lock_version: 0, decision: "renew")
      end

      record.reload
      assert_equal "renew", record.decision
      assert_equal now, record.decided_at
      assert_equal 1, record.lock_version
      assert_equal %w[contract_created decision_recorded], record.events.map(&:event_type)
      event = record.events.last
      assert_equal({ "decision" => "renew" }, event.payload)
      assert_equal @owner, event.actor
      assert_equal record.decided_at, event.created_at

      restored = ContractMapper.load(record)
      assert_equal "renew", restored.decision
      assert_equal now, restored.decided_at
    end

    test "stale versions fail before the domain transition" do
      record = create_contract
      ContractWriter.record_decision(owner: @owner, id: record.id, lock_version: 0, decision: "renew")

      error = assert_raises(StaleVersion) do
        ContractWriter.record_decision(owner: @owner, id: record.id, lock_version: 0, decision: "do_not_renew")
      end
      assert_equal record.id, error.contract_id
      assert_equal 0, error.expected_version
      assert_equal 1, error.current_version
      assert_equal "The contract has changed since it was opened", error.message

      assert_raises(Errors::ContractAlreadyDecided) do
        ContractWriter.record_decision(owner: @owner, id: record.id, lock_version: 1, decision: "do_not_renew")
      end
      assert_equal 2, record.events.count
    end

    test "another owner cannot change a contract or record a decision" do
      record = create_contract
      other = users(:other)

      assert_raises(ActiveRecord::RecordNotFound) do
        ContractWriter.update(owner: other, id: record.id, lock_version: 0, title: "Other owner")
      end
      assert_raises(ActiveRecord::RecordNotFound) do
        ContractWriter.record_decision(owner: other, id: record.id, lock_version: 0, decision: "renew")
      end
      assert_equal "Office Internet", record.reload.title
      assert_nil record.decision
      assert_equal 1, record.events.count
    end

    test "creation is rolled back when its event cannot be saved" do
      assert_no_difference [ "ContractRecord.count", "ContractEvent.count" ] do
        assert_event_rejected("contract_created") { create_contract }
      end
    end

    test "editing the schedule is rolled back when its event cannot be saved" do
      record = create_contract
      assert_event_rejected("contract_updated") do
        ContractWriter.update(owner: @owner, id: record.id, lock_version: 0, notice_days: 31)
      end

      record.reload
      assert_equal 30, record.notice_days
      assert_equal Date.new(2026, 12, 1), record.notice_due_on
      assert_equal 1, record.schedule_revision
      assert_equal 0, record.lock_version
      assert_equal 1, record.events.count
    end

    test "recording a decision is rolled back when its event cannot be saved" do
      record = create_contract
      assert_event_rejected("decision_recorded") do
        ContractWriter.record_decision(owner: @owner, id: record.id, lock_version: 0, decision: "renew")
      end

      record.reload
      assert_nil record.decision
      assert_nil record.decided_at
      assert_equal 0, record.lock_version
      assert_equal 1, record.events.count
    end

    private

    def create_contract(**attributes)
      defaults = { owner: @owner, title: "Office Internet", counterparty: "Example Telecom", ends_on: Date.new(2026, 12, 31), notice_days: 30 }
      ContractWriter.create(**defaults.merge(attributes))
    end

    def assert_event_rejected(event_type)
      ContractEvent.with_connection do |connection|
        connection.execute(<<~SQL)
          ALTER TABLE contract_events
          ADD CONSTRAINT reject_test_event CHECK (event_type <> #{connection.quote(event_type)}) NOT VALID
        SQL
      end

      error = assert_raises(ActiveRecord::StatementInvalid) { yield }
      assert_instance_of PG::CheckViolation, error.cause
      assert_equal "reject_test_event", error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
    end
  end
end
