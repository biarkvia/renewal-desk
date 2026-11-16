module Api
  module V1
    class ContractsController < ApplicationController
      use BadRequestResponse

      rescue_from StandardError, with: :render_internal_error
      include ContractAccess

      wrap_parameters false
      rescue_from ActionController::InvalidAuthenticityToken, with: :render_csrf_error
      rescue_from ActionDispatch::Http::Parameters::ParseError, with: :render_invalid_json

      def index
        render json: contracts_for(view_filter).map { |contract| resource(contract) }
      end

      def show
        render json: resource(contract_scope.find(contract_id))
      end

      def create
        contract = writer.create(owner: current_user, **input.create_attributes)
        render json: resource(contract), status: :created, location: api_v1_contract_url(contract)
      end

      def update
        contract = writer.update(owner: current_user, id: contract_id, **input.update_attributes)
        render json: resource(contract)
      end

      def decision
        contract = writer.record_decision(owner: current_user, id: contract_id, **input.decision_attributes)
        render json: resource(contract)
      end

      private

      def input
        unless request.media_type == "application/json" && request.raw_post.present?
          raise ContractInput::Error.new("Send a JSON object in the request body.", status: 400, code: "invalid_request")
        end

        ContractInput.new(request.request_parameters)
      end

      def require_authentication
        return if current_user

        render_problem ContractProblem.new(status: 401, code: "authentication_required", detail: "Sign in to access contracts.")
      end

      def request_authenticity_tokens
        [ request.x_csrf_token ]
      end

      def render_contract_error(error)
        render_problem ContractProblem.from(error)
      end

      def render_csrf_error
        render_problem ContractProblem.new(status: 403, code: "csrf_invalid", detail: "Supply a valid CSRF token for this session.")
      end

      def render_invalid_json
        render_problem ContractProblem.new(status: 400, code: "invalid_request", detail: "Send valid JSON in the request body.")
      end

      def render_internal_error(error)
        Rails.error.report(error, handled: true, severity: :error)
        render_problem ContractProblem.new(status: 500, code: "internal_error", detail: "The request could not be completed.")
      end

      def render_problem(problem)
        render json: problem, status: problem.status, content_type: "application/problem+json"
      end

      def resource(contract)
        {
          id: contract.id,
          title: contract.title,
          counterparty: contract.counterparty,
          ends_on: contract.ends_on.iso8601,
          notice_days: contract.notice_days,
          notice_due_on: contract.notice_due_on.iso8601,
          decision: contract.decision,
          decided_at: contract.decided_at&.utc&.iso8601(6),
          lock_version: contract.lock_version
        }
      end
    end
  end
end
