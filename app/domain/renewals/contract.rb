# frozen_string_literal: true

module Renewals
  class Contract
    DETAILS_MAX_LENGTH = 160
    DECISIONS = %w[renew do_not_renew].freeze

    attr_reader :id, :title, :counterparty, :schedule_revision, :decision, :decided_at

    def initialize(title:, counterparty:, ends_on:, notice_days:, id: nil, schedule_revision: 1, decision: nil, decided_at: nil)
      @id = validate_id(id)
      @title = validate_details(:title, title)
      @counterparty = validate_details(:counterparty, counterparty)
      @schedule = NoticeSchedule.new(ends_on: ends_on, notice_days: notice_days)
      @schedule_revision = validate_revision(schedule_revision)
      @decision = nil
      @decided_at = nil

      if decision.nil?
        unless decided_at.nil?
          raise Errors::InvalidState.new(field: :decided_at, value: decided_at, message: "An open contract cannot have a decision timestamp")
        end
      else
        record_decision(decision: decision, decided_at: decided_at)
      end
    end

    def update_details(title: @title, counterparty: @counterparty, ends_on: @schedule.ends_on, notice_days: @schedule.notice_days)
      ensure_open!
      title = validate_details(:title, title)
      counterparty = validate_details(:counterparty, counterparty)
      schedule = NoticeSchedule.new(ends_on: ends_on, notice_days: notice_days)

      @schedule_revision += 1 if schedule.notice_due_on != notice_due_on
      @title = title
      @counterparty = counterparty
      @schedule = schedule
    end

    def record_decision(decision:, decided_at:)
      ensure_open!
      choice = DECISIONS.find { |option| option == decision }
      raise Errors::InvalidDecision.new(value: decision) unless choice
      unless decided_at.is_a?(Time)
        raise Errors::InvalidState.new(field: :decided_at, value: decided_at, message: "A recorded decision requires a timestamp")
      end

      @decision = choice
      @decided_at = decided_at.getutc.freeze
    end

    def open?
      decision.nil?
    end

    def ends_on = @schedule.ends_on
    def notice_days = @schedule.notice_days
    def notice_due_on = @schedule.notice_due_on

    def overdue?(today:)
      open? && @schedule.overdue?(today: today)
    end

    def due_today?(today:)
      open? && @schedule.due_today?(today: today)
    end

    def due_for_reminder?(today:)
      open? && @schedule.due_for_reminder?(today: today)
    end

    private

    def validate_id(value)
      unless value.nil? || (value.is_a?(Integer) && value.positive?)
        raise Errors::InvalidState.new(field: :id, value: value, message: "Contract ID must be a positive integer")
      end

      value
    end

    def validate_details(field, value)
      text = utf8_text(value)
      trimmed = text.strip if text && !text.include?("\0")
      unless trimmed && (1..DETAILS_MAX_LENGTH).cover?(trimmed.length)
        raise Errors::InvalidDetails.new(field: field, value: value, maximum: DETAILS_MAX_LENGTH)
      end

      trimmed.freeze
    end

    def utf8_text(value)
      return unless value.is_a?(String) && value.valid_encoding?

      value.encode(Encoding::UTF_8)
    rescue EncodingError
      nil
    end

    def validate_revision(value)
      unless value.is_a?(Integer) && value.positive?
        raise Errors::InvalidState.new(field: :schedule_revision, value: value, message: "Schedule revision must be a positive integer")
      end

      value
    end

    def ensure_open!
      raise Errors::ContractAlreadyDecided.new(contract_id: id, decision: decision) unless open?
    end
  end
end
