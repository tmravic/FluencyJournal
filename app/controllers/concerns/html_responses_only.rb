# Writes answer HTML or Turbo Stream only. Without this, a request for any
# other format (the JSON variants were removed) would still run the write
# and only then fail to find a matching response.
module HtmlResponsesOnly
  extend ActiveSupport::Concern

  included do
    before_action :require_html_or_turbo_stream, only: %i[create update destroy]
  end

  private

  def require_html_or_turbo_stream
    head :not_acceptable unless request.format.html? || request.format.turbo_stream?
  end
end
