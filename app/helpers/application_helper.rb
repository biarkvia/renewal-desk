module ApplicationHelper
  DECISION_LABELS = { "renew" => "Renew", "do_not_renew" => "Do not renew" }.freeze
  EVENT_LABELS = {
    "contract_created" => "Contract added",
    "contract_updated" => "Contract updated",
    "decision_recorded" => "Decision recorded"
  }.freeze
  HISTORY_FIELD_LABELS = {
    "title" => "Contract name", "counterparty" => "Counterparty", "ends_on" => "End date",
    "notice_days" => "Notice period", "notice_due_on" => "Notice deadline"
  }.freeze

  def decision_label(decision)
    DECISION_LABELS.fetch(decision)
  end

  def contract_badge(record)
    contract = Renewals::ContractMapper.load(record)
    today = Date.current
    label, tone = if contract.decision
      [ decision_label(contract.decision), contract.decision == "renew" ? "positive" : "muted" ]
    elsif contract.overdue?(today: today)
      [ "Overdue", "overdue" ]
    elsif contract.due_today?(today: today)
      [ "Due today", "today" ]
    else
      [ "Open", "neutral" ]
    end

    tag.span(label, class: "badge badge--#{tone}")
  end

  def contract_date(date)
    tag.time(date.strftime("%-d %b %Y"), datetime: date.iso8601)
  end

  def event_time(time)
    tag.time(time.strftime("%-d %b %Y, %H:%M"), datetime: time.iso8601)
  end

  def event_label(event)
    EVENT_LABELS.fetch(event.event_type)
  end

  def visible_changes(event)
    event.payload.slice(*HISTORY_FIELD_LABELS.keys).map do |field, change|
      [ HISTORY_FIELD_LABELS.fetch(field), history_value(field, change.fetch("from")), history_value(field, change.fetch("to")) ]
    end
  end

  def history_value(field, value)
    return contract_date(Date.iso8601(value, Date::GREGORIAN)) if %w[ends_on notice_due_on].include?(field)

    value.to_s
  end
end
