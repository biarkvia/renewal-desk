module Api
  module V1
    class BadRequestResponse
      def initialize(app)
        @app = app
      end

      def call(env)
        @app.call(env)
      rescue ActionController::BadRequest
        # Rails can reject conflicting parameters before action error handlers run.
        problem = ContractProblem.new(status: 400, code: "invalid_request", detail: "Send valid request parameters.")
        [ problem.status, { "content-type" => "application/problem+json", "cache-control" => "no-store" }, [ problem.to_json ] ]
      end
    end
  end
end
