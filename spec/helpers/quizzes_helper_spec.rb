require 'rails_helper'

RSpec.describe QuizzesHelper, type: :helper do
  describe "#render_ai_query_entry_content" do
    let(:user) { instance_double(User, original_language: "English") }

    def grade_query(content, explanation)
      query = AiQuery.new(
        raw_response: {
          entry_1: { content: content, explanation_en: explanation }
        }.to_json
      )
      output = AiOutput.new(identifier: "1")
      allow(query).to receive(:user).and_return(user)
      allow(query).to receive(:find_ai_output_by_identifier).with("1").and_return(output)
      query
    end

    it "shows both sides when the grade uses an arrow" do
      query = grade_query("Test → 本当の文", "This is not a real attempt.")

      html = helper.render_ai_query_entry_content(query, "1", "entry_", user, nil, html: true)

      expect(html).to include("Test")
      expect(html).to include("本当の文")
      expect(html).to include("↓")
      expect(html).to include("(This is not a real attempt.)")
    end

    it "shows the sentence and explanation when the grade has no arrow" do
      query = grade_query(
        "真優の誕生日とクリスマスが同じ週にあるので、一度にたくさんのプレゼントをもらうことができます。",
        "No quiz answer provided to compare."
      )

      html = helper.render_ai_query_entry_content(query, "1", "entry_", user, nil, html: true)

      expect(html).to include("真優の誕生日とクリスマスが同じ週にある")
      expect(html).to include("(No quiz answer provided to compare.)")
      expect(html).not_to include("↓")
    end
  end
end
