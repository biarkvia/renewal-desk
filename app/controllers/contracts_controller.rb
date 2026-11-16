class ContractsController < ApplicationController
  include ContractAccess

  before_action :load_contract, only: [ :show, :edit, :update, :decision ]

  def index
    @view = view_filter
    @contracts = contracts_for(@view)
  end

  def show
  end

  def new
    @form = {}
  end

  def create
    @form = form_values
    contract = writer.create(owner: current_user, **ContractInput.new(@form, form: true).create_attributes)
    redirect_to contract_path(contract), status: :see_other, notice: "Contract added."
  end

  def edit
    if @contract.decision
      raise Renewals::Errors::ContractAlreadyDecided.new(contract_id: @contract.id, decision: @contract.decision)
    end

    @form = @contract.slice(*ContractInput::DETAILS, "lock_version")
  end

  def update
    @form = form_values
    writer.update(owner: current_user, id: @contract.id, **ContractInput.new(@form, form: true).update_attributes)
    redirect_to contract_path(@contract), status: :see_other, notice: "Contract saved."
  end

  def decision
    input = ContractInput.new(form_values, form: true)
    writer.record_decision(owner: current_user, id: @contract.id, **input.decision_attributes)
    redirect_to contract_path(@contract), status: :see_other, notice: "Decision recorded."
  end

  private

  def load_contract
    @contract = contract_scope.find(contract_id)
  end

  def form_values
    fields = request.request_parameters["contract"]
    return {} unless fields.is_a?(Hash)

    ActionController::Parameters.new(fields).permit(*ContractInput::FORM_FIELDS).to_h
  end

  def render_contract_error(error)
    @problem = ContractProblem.from(error)
    template = if @problem.status == 422
      { "create" => :new, "update" => :edit, "decision" => :show }.fetch(action_name, :error)
    else
      :error
    end

    render template, status: @problem.status
  end
end
