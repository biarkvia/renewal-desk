require "test_helper"
require "timeout"

module Renewals
  class DecisionConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    teardown do
      if @record
        ContractEvent.where(contract_id: @record.id).delete_all
        @record.delete
      end
    end

    test "two concurrent decisions from the same version leave exactly one recorded decision" do
      owner = users(:owner)
      @record = ContractWriter.create(
        owner: owner, title: "Office Internet", counterparty: "Example Telecom", ends_on: Date.new(2026, 12, 31), notice_days: 30
      )
      record_id = @record.id
      version = @record.lock_version
      ready = Queue.new
      start = Queue.new

      workers = %w[renew do_not_renew].map do |decision|
        Thread.new do
          ContractRecord.with_connection do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()")
            start.pop
            ContractWriter.record_decision(owner: owner, id: record_id, lock_version: version, decision: decision)
          end
        rescue StaleVersion => error
          error
        end
      end

      results = Timeout.timeout(10) do
        assert_equal 2, workers.map { ready.pop }.uniq.size
        workers.size.times { start << true }
        workers.map(&:value)
      end

      saved = results.grep(ContractRecord).sole
      rejected = results.grep(StaleVersion).sole
      event = @record.events.where(event_type: "decision_recorded").sole
      assert_equal 1, @record.reload.lock_version
      assert_equal saved.decision, @record.decision
      assert_equal saved.decision, event.payload.fetch("decision")
      assert_equal 1, rejected.current_version
    ensure
      workers&.each do |worker|
        worker.kill if worker.alive?
        worker.join
      end
    end
  end
end
