# frozen_string_literal: true

require "date"

module Renewals
  class NoticeSchedule
    MINIMUM_NOTICE_DAYS = 0
    MAXIMUM_NOTICE_DAYS = 365
    REMINDER_LEAD_DAYS = 7
    SUPPORTED_YEARS = 1..9999

    attr_reader :ends_on, :notice_days, :notice_due_on

    def initialize(ends_on:, notice_days:)
      @ends_on = calendar_date(ends_on, field: :ends_on)
      unless notice_days.is_a?(Integer) && (MINIMUM_NOTICE_DAYS..MAXIMUM_NOTICE_DAYS).cover?(notice_days)
        raise Errors::InvalidNoticePeriod.new(value: notice_days, minimum: MINIMUM_NOTICE_DAYS, maximum: MAXIMUM_NOTICE_DAYS)
      end

      @notice_days = notice_days
      @notice_due_on = calendar_date(@ends_on - notice_days, field: :notice_due_on)
      freeze
    end

    def due_for_reminder?(today:)
      notice_due_on <= calendar_date(today, field: :today) + REMINDER_LEAD_DAYS
    end

    def overdue?(today:)
      calendar_date(today, field: :today) > notice_due_on
    end

    def due_today?(today:)
      calendar_date(today, field: :today) == notice_due_on
    end

    private

    def calendar_date(value, field:)
      unless value.instance_of?(Date) && SUPPORTED_YEARS.cover?(value.year) &&
          Date.valid_date?(value.year, value.month, value.day, Date::GREGORIAN)
        raise Errors::InvalidDate.new(field: field, value: value)
      end

      Date.new(value.year, value.month, value.day, Date::GREGORIAN).freeze
    end
  end
end
