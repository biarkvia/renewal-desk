module ContractAccess
  extend ActiveSupport::Concern

  VIEWS = %w[open decided all].freeze

  included do
    rescue_from ContractInput::Error, ActiveRecord::RecordNotFound, Renewals::StaleVersion,
      Renewals::Errors::ContractAlreadyDecided, Renewals::Errors::InvalidDate, Renewals::Errors::InvalidNoticePeriod,
      Renewals::Errors::InvalidDecision, Renewals::Errors::InvalidDetails, with: :render_contract_error
  end

  private

  def view_filter
    view = request.query_parameters.fetch("view", "open")
    return view if VIEWS.include?(view)

    raise ContractInput::Error.new("View must be open, decided, or all.", status: 400, code: "invalid_request")
  end

  def contracts_for(view)
    ordered = contract_scope.order(:notice_due_on, :id)
    case view
    when "open" then ordered.where(decision: nil)
    when "decided" then ordered.where.not(decision: nil)
    else ordered
    end
  end

  def contract_scope
    ContractRecord.where(owner: current_user)
  end

  def contract_id
    id = request.path_parameters.fetch(:id)
    return id if /\A[1-9][0-9]{0,18}\z/.match?(id)

    raise ActiveRecord::RecordNotFound
  end

  def writer
    Renewals::ContractWriter
  end
end
