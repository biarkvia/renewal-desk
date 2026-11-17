require "test_helper"
require "timeout"

class ReminderConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @today = Date.new(2026, 12, 1)
    @record = Renewals::ContractWriter.create(
      owner: users(:owner), title: "Office Internet", counterparty: "Example Telecom", ends_on: @today + 30, notice_days: 30
    )
    @workers = []
  end

  teardown do
    @workers&.each do |worker|
      worker.kill if worker.alive?
      worker.join
    end
    [ @record, @other_record ].compact.each do |record|
      Reminder.where(contract_id: record.id).delete_all
      ContractEvent.where(contract_id: record.id).delete_all
      record.delete
    end
  end

  test "overlapping jobs on separate PostgreSQL connections create one row" do
    ContractRecord.with_connection do |connection|
      ContractRecord.transaction do
        ContractRecord.lock.find(@record.id)
        first = start_worker
        second = start_worker
        assert_equal 2, [ first, second ].uniq.size
        wait_for_row_lock(connection, first, second)
      end
    end
    finish_workers

    assert_equal [ 1 ], @record.reminders.pluck(:schedule_revision)
  end

  test "ignores a stale candidate if an edit moves its deadline before the lock is acquired" do
    ContractRecord.with_connection do |connection|
      ContractRecord.transaction do
        ContractRecord.lock.find(@record.id)
        wait_for_row_lock(connection, start_worker)
        Renewals::ContractWriter.update(owner: @record.owner, id: @record.id, lock_version: 0, notice_days: 0)
      end
    end
    finish_workers

    assert_equal @today + 30, @record.reload.notice_due_on
    assert_empty @record.reminders
  end

  test "can resume after an insert fails partway through a batch" do
    @other_record = Renewals::ContractWriter.create(
      owner: users(:owner), title: "Office cleaning", counterparty: "Example Cleaning", ends_on: @today, notice_days: 0
    )
    Reminder.with_connection do |connection|
      connection.execute(<<~SQL)
        ALTER TABLE reminders ADD CONSTRAINT reject_test_reminder CHECK (contract_id <> #{Integer(@other_record.id)})
      SQL
      error = assert_raises(ActiveRecord::StatementInvalid) { Renewals::IssueReminders.call(today: @today) }
      assert_instance_of PG::CheckViolation, error.cause
    ensure
      connection.execute("ALTER TABLE reminders DROP CONSTRAINT IF EXISTS reject_test_reminder")
    end

    issued = @record.current_reminder
    assert_predicate issued, :present?
    assert_nil @other_record.current_reminder
    assert_difference "Reminder.count", 1 do
      Renewals::IssueReminders.call(today: @today)
    end
    assert_equal issued.id, @record.current_reminder.id
    assert_predicate @other_record.current_reminder, :present?
  end

  private

  def start_worker
    ready = Queue.new
    @workers << Thread.new do
      ContractRecord.with_connection do |connection|
        ready << connection.select_value("SELECT pg_backend_pid()")
        Renewals::IssueReminders.call(today: @today)
      end
    end
    Timeout.timeout(10) { ready.pop }
  end

  def wait_for_row_lock(connection, *worker_pids)
    ContractRecord.uncached do
      Timeout.timeout(10) do
        until worker_pids.all? { |pid| connection.select_value("SELECT cardinality(pg_blocking_pids(#{Integer(pid)}))").positive? }
          Thread.pass
        end
      end
    end
  end

  def finish_workers
    Timeout.timeout(10) { @workers.each(&:value) }
  end
end
