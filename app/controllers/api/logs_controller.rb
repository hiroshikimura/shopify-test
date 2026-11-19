# frozen_string_literal: true

class Api::LogsController < AuthenticatedController
  def index
    logs = CommunicationLog.recent.limit(20)
    render(json: logs.as_json(only: %i[id direction category http_method url status duration_ms error created_at]))
  end
end
