require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#back_link" do
    it "renders a left-arrow link to the path" do
      html = helper.back_link("Back to journals", "/journals")

      expect(html).to eq(%(<a href="/journals">← Back to journals</a>))
    end

    it "renders exactly what the inline link_to sanitize expression rendered" do
      text = "Back & forth"

      expect(helper.back_link(text, "/notes"))
        .to eq(helper.link_to(helper.sanitize("&larr; #{text}"), "/notes"))
    end
  end
end
