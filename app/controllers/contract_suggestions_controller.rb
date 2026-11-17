class ContractSuggestionsController < ApplicationController
  before_action :load_provider
  rate_limit to: 6, within: 1.minute, by: -> { current_user.id }, only: :create, with: -> { render_rate_limit }

  def new
    @excerpt = ContractExtraction::DemoProvider::SAMPLE if demo_provider?
  end

  def create
    excerpt = request.request_parameters["contract_excerpt"]
    @excerpt = excerpt if excerpt.is_a?(String)
    @suggestions = ContractExtraction::Extractor.new(provider: @provider).call(@excerpt)
    if @suggestions.any?
      values = @suggestions.transform_values { |suggestion| suggestion.fetch(:value).to_s }
      @proposal = verifier.generate(values, purpose: proposal_purpose, expires_in: 15.minutes)
    end

    render :new
  rescue ContractExtraction::InvalidExcerpt => error
    render_error(error.message, status: :unprocessable_content)
  rescue ContractExtraction::InvalidResponse
    render_error("The suggested terms could not be verified against the excerpt. Enter the details manually or try again.", status: :bad_gateway)
  rescue ContractExtraction::Unavailable
    render_error("Text extraction is temporarily unavailable. Enter the details manually or try again.", status: :service_unavailable)
  end

  def apply
    token = request.request_parameters["proposal"]
    @form = verifier.verified(token, purpose: proposal_purpose) if token.is_a?(String)
    if @form
      render "contracts/new"
    else
      render_error("These suggestions have expired. Request new suggestions or enter the details manually.", status: :unprocessable_content)
    end
  end

  private

  helper_method :demo_provider?

  def load_provider
    @provider = ContractExtraction.provider
  end

  def demo_provider?
    @provider.is_a?(ContractExtraction::DemoProvider)
  end

  def render_rate_limit
    render_error("Too many extraction requests. Try again in a minute or enter the details manually.", status: :too_many_requests)
  end

  def render_error(message, status:)
    @extraction_error = message
    render :new, status: status
  end

  def verifier
    Rails.application.message_verifier(:contract_suggestion)
  end

  def proposal_purpose
    "contract-suggestion:#{current_user.id}"
  end
end
