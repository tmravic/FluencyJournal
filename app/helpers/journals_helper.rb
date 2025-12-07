module JournalsHelper
  def query_unrelated_to_quizzes?(query)
    quiz_prompts = ["PrepareQuizPrompt", "QuizResultPrompt"]
    query.quizzes.empty? && !quiz_prompts.include?(query.prompt.class.name)
  end
end
