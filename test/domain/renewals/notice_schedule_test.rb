require "minitest/autorun"

module Renewals
  class NoticeScheduleTest < Minitest::Test
    def test_notice_period_includes_zero_and_365_days
      assert_equal Date.new(2026, 12, 31), schedule(notice_days: 0).notice_due_on
      assert_equal Date.new(2025, 12, 31), schedule(notice_days: 365).notice_due_on
    end

    def test_deadline_crosses_month_year_and_leap_day_boundaries
      assert_equal Date.new(2026, 12, 1), schedule.notice_due_on
      assert_equal Date.new(2025, 12, 16), schedule(ends_on: Date.new(2026, 1, 15)).notice_due_on
      assert_equal Date.new(2024, 2, 29), schedule(ends_on: Date.new(2024, 3, 1), notice_days: 1).notice_due_on
    end

    def test_uses_the_gregorian_calendar_before_its_historical_adoption
      deadline = schedule(ends_on: Date.new(1582, 10, 15), notice_days: 5).notice_due_on

      assert_equal "1582-10-10", deadline.iso8601
      assert_equal Date::GREGORIAN, deadline.start
    end

    def test_invalid_notice_periods_expose_the_rejected_value_and_bounds
      [ -1, 366, "30", 30.0, nil ].each do |value|
        error = assert_raises(Errors::InvalidNoticePeriod) { schedule(notice_days: value) }

        value.nil? ? assert_nil(error.value) : assert_same(value, error.value)
        assert_equal 0, error.minimum
        assert_equal 365, error.maximum
        assert_equal "Notice period must be between 0 and 365 days", error.message
      end
    end

    def test_rejects_non_dates_and_dates_outside_the_supported_gregorian_range
      [ "2026-12-31", DateTime.new(2026, 12, 31), Date.new(0, 12, 31), Date.new(10_000, 1, 1), Date.new(1500, 2, 29) ].each do |value|
        error = assert_raises(Errors::InvalidDate) { schedule(ends_on: value) }

        assert_equal :ends_on, error.field
        assert_same value, error.value
        assert_equal "ends_on must be a Gregorian date between 0001-01-01 and 9999-12-31", error.message
      end
    end

    def test_lowest_supported_end_date_cannot_produce_a_deadline_in_year_zero
      first_day = Date.new(1, 1, 1, Date::GREGORIAN)
      assert_equal first_day, schedule(ends_on: first_day, notice_days: 0).notice_due_on

      error = assert_raises(Errors::InvalidDate) { schedule(ends_on: first_day, notice_days: 1) }
      assert_equal :notice_due_on, error.field
      assert_equal 0, error.value.year
    end

    def test_reminder_window_includes_the_seventh_day_and_overdue_contracts
      notice = schedule

      refute notice.due_for_reminder?(today: Date.new(2026, 11, 23))
      assert notice.due_for_reminder?(today: Date.new(2026, 11, 24))
      assert notice.due_for_reminder?(today: Date.new(2026, 12, 1))
      assert notice.due_for_reminder?(today: Date.new(2026, 12, 2))
      assert notice.due_today?(today: Date.new(2026, 12, 1))
      refute notice.overdue?(today: Date.new(2026, 12, 1))
      assert notice.overdue?(today: Date.new(2026, 12, 2))
    end

    private

    def schedule(ends_on: Date.new(2026, 12, 31), notice_days: 30)
      NoticeSchedule.new(ends_on: ends_on, notice_days: notice_days)
    end
  end
end
