module JournalsHelper
  def query_unrelated_to_quizzes?(query)
    prompt = query.prompt
    return false if query.quizzes.any?
    return false if prompt.is_a?(PrepareQuizPrompt) || prompt.is_a?(QuizResultPrompt)

    # Retired hint prompts are the base Prompt class. They have no show page.
    prompt.listable?
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
