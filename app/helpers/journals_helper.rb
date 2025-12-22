module JournalsHelper
  def query_unrelated_to_quizzes?(query)
    quiz_prompts = ["PrepareQuizPrompt", "QuizResultPrompt"]
    query.quizzes.empty? && !quiz_prompts.include?(query.prompt.class.name)
  end

  def all_or_todays
    if @todays_journals.present?
      "todays"
    else
      "all"
    end
  end

  def all_journals_empty?
    @from_all_or_todays == "all" && @all_journals.empty?
  end

  def todays_journals_empty?
    @from_all_or_todays == "todays" && @todays_journals.empty?
  end
end
