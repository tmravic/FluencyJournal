require "rails_helper"

RSpec.describe XAiService do
  describe "#call" do
    it "raises ApiError with the response status and body when xAI rejects the request" do
      response = instance_double(
        Faraday::Response,
        success?: false,
        status: 404,
        body: '{"code":"not-found","error":"The model grok-4.6 does not exist or your team does not have access to it."}'
      )
      service = described_class.new(api_key: "key", prompt: double, user: double, journal: double)
      allow(service).to receive(:make_call_to_x_api).and_return(response)

      expect { service.call }.to raise_error(described_class::ApiError) do |error|
        expect(error.status).to eq(404)
        expect(error.body).to include("not-found")
        expect(error.message).to include("xAI API 404:")
      end
    end
  end
end
