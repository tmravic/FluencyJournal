require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#language_code" do
    it "capitalizes the shared Prompt language codes" do
      expect(helper.send(:language_code, "English")).to eq("En")
      expect(helper.send(:language_code, "Japanese")).to eq("Ja")
    end

    it "falls back to the first two letters" do
      expect(helper.send(:language_code, "Thai")).to eq("Th")
    end
  end
end
