require 'rails_helper'

# Specs in this file have access to a helper object that includes
# the JournalsHelper. For example:
#
# describe JournalsHelper do
#   describe "string concat" do
#     it "concats two strings with spaces" do
#       expect(helper.concat_strings("this","that")).to eq("this that")
#     end
#   end
# end
RSpec.describe JournalsHelper, type: :helper do
  def query_for(prompt, quizzes: [])
    instance_double(AiQuery, prompt: prompt, quizzes: quizzes)
  end

  it "links a normal question" do
    query = query_for(FreeQuestionPrompt.new)

    expect(helper.query_unrelated_to_quizzes?(query)).to be true
  end

  it "hides a retired hint prompt that has no show page" do
    query = query_for(Prompt.new)

    expect(helper.query_unrelated_to_quizzes?(query)).to be false
  end

  it "hides quiz preparation and graded quizzes" do
    expect(helper.query_unrelated_to_quizzes?(query_for(PrepareQuizPrompt.new))).to be false
    expect(helper.query_unrelated_to_quizzes?(query_for(PrepareQuizPrompt.new, quizzes: [ instance_double(Quiz) ]))).to be false
    expect(helper.query_unrelated_to_quizzes?(query_for(QuizResultPrompt.new))).to be false
    expect(helper.query_unrelated_to_quizzes?(query_for(QuizResultPrompt.new, quizzes: [ instance_double(Quiz) ]))).to be false
  end
end
