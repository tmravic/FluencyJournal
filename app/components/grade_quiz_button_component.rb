class GradeQuizButtonComponent < ApplicationComponent
  def initialize(journal:, quiz:)
    @journal = journal
    @quiz = quiz
  end
end
