require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#render_ai_query_change_content" do
    let(:blank_change) do
      AiQuery.new(
        raw_response: {
          "change_1" => { "content" => "", "explanation_en" => "Direct translation." },
          "corrected_text" => "ハリーポッターの話は、マルフォイが女の子でも成立すると思う"
        }.to_json
      )
    end

    it "renders nothing for a blank change instead of calling first on nil" do
      expect(helper.render_ai_query_change_content(blank_change, "1", "change_", nil, html: true)).to be_nil
    end

    it "renders nothing for a missing line, a whitespace line, and a non-object body" do
      missing = AiQuery.new(raw_response: '{"change_1":{"explanation_en":"No content."}}')
      spaces = AiQuery.new(raw_response: '{"change_1":{"content":"   ","explanation_en":"Spaces."}}')
      broken = AiQuery.new(raw_response: "not json")

      expect(helper.render_ai_query_change_content(missing, "1", "change_", nil, html: true)).to be_nil
      expect(helper.render_ai_query_change_content(spaces, "1", "change_", nil, html: false)).to be_nil
      expect(helper.render_ai_query_change_content(broken, "1", "change_", nil, html: true)).to be_nil
    end

    it "still renders both sides of a real change" do
      query = AiQuery.new(
        raw_response: '{"change_1":{"content":"小さい針 → マイクロニードル","explanation_en":"Use the usual word."}}'
      )
      user = instance_double(User, original_language: "English")
      allow(query).to receive(:user).and_return(user)

      html = helper.render_ai_query_change_content(query, "1", "change_", user, html: true)

      expect(html).to include("小さい針")
      expect(html).to include("マイクロニードル")
      expect(html).to include("Use the usual word.")
    end

    it "still renders a followup sentence that has no arrow" do
      query = AiQuery.new(
        raw_response: '{"change_1":{"content":"願い (ねが)い","explanation_en":"The reading is ねがい."}}'
      )
      user = instance_double(User, original_language: "English")
      allow(query).to receive(:user).and_return(user)

      html = helper.render_ai_query_change_content(query, "1", "change_", user, html: true)

      expect(html).to include("願い (ねが)い")
      expect(html).to include("The reading is ねがい.")
    end
  end
end
