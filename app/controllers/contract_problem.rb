ContractProblem = Data.define(:status, :code, :detail, :field) do
  def initialize(status:, code:, detail:, field: nil)
    super(status: status, code: code, detail: detail, field: field)
  end

  def self.from(error)
    case error
    when ContractInput::Error
      new(status: error.status, code: error.code, detail: error.message, field: error.field)
    when ActiveRecord::RecordNotFound
      new(status: 404, code: "contract_not_found", detail: "This contract could not be found.")
    when Renewals::StaleVersion
      new(status: 409, code: "stale_version", detail: "This contract changed while it was open. Reload it to see the latest version.")
    when Renewals::Errors::ContractAlreadyDecided
      new(status: 409, code: "contract_already_decided", detail: "A renewal decision has already been recorded.")
    when Renewals::Errors::InvalidDate
      new(status: 422, code: "invalid_date", detail: error.message, field: error.field.to_s)
    when Renewals::Errors::InvalidNoticePeriod
      new(status: 422, code: "invalid_notice_period", detail: error.message, field: "notice_days")
    when Renewals::Errors::InvalidDecision
      new(status: 422, code: "invalid_decision", detail: error.message, field: "decision")
    when Renewals::Errors::InvalidDetails
      new(status: 422, code: "invalid_input", detail: error.message.humanize, field: error.field.to_s)
    end
  end

  def as_json(*)
    { type: "about:blank", title: Rack::Utils::HTTP_STATUS_CODES.fetch(status), status: status, code: code, detail: detail, field: field }.compact
  end
end
