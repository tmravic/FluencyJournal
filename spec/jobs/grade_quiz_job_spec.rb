require "rails_helper"

RSpec.describe GradeQuizJob, type: :job do
  def create_quiz
    group = Group.create!(name: "Grade job #{SecureRandom.hex(4)}")
    user = User.create!(
      email_address: "grade-job-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
    journal = Journal.create!(title: "Grade journal", user: user, group: group, last_interval: 1)
    journal.entries.create!(content: "彼女のお母さんに会いました。")
    prepare_prompt = PrepareQuizPrompt.create!(
      raw_prompt: "prepare",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid,
      sent_role_prompt: "role"
    )
    prepare_query = AiQuery.create!(journal: journal, prompt: prepare_prompt, raw_response: "{}")
    prepare_query.ai_outputs.create!(identifier: "1", content: "PREPARE_QUESTION_ONLY", made_note: false)
    grade_prompt = QuizResultPrompt.create!(
      raw_prompt: "grade",
      ai_model: "grok-4-fast-non-reasoning",
      uuid: SecureRandom.uuid,
      sent_role_prompt: "role"
    )
    quiz = Quiz.create!(journal: journal, ai_query: prepare_query)

    [ user, journal, quiz, prepare_query, grade_prompt ]
  end

  def grade_result
    body = {
      "entry_1" => {
        "content" => "会いました → 会いました",
        "explanation_en" => "GRADE_EXPLANATION_UNIQUE"
      },
      "assessment" => "GRADE_ASSESSMENT_UNIQUE"
    }

    XAiChat::Result.new(
      raw_response: body.to_json,
      parsed: body,
      prompt_tokens: 3,
      completion_tokens: 4,
      total_tokens: 7
    )
  end

  it "stores the grade on grading_ai_query_id and leaves the question query in place" do
    _user, journal, quiz, prepare_query, grade_prompt = create_quiz
    allow(XAiChat).to receive(:complete).and_return(grade_result)
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)

    GradeQuizJob.perform_now(journal, grade_prompt, quiz)

    quiz.reload
    grade_query = quiz.grading_ai_query
    expect(quiz.ai_query_id).to eq(prepare_query.id)
    expect(grade_query).to be_present
    expect(grade_query.id).not_to eq(prepare_query.id)
    expect(prepare_query.quizzes).to contain_exactly(quiz)
    expect(grade_query.quizzes).to be_empty
    expect(grade_query.graded_quizzes).to contain_exactly(quiz)
    expect(grade_query.assessment).to eq("GRADE_ASSESSMENT_UNIQUE")
    expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to).with(
      "channel_#{grade_prompt.uuid}",
      target: "quiz_results",
      partial: "quizzes/graded_output",
      locals: hash_including(ai_query_id: grade_query.id, assessment: "GRADE_ASSESSMENT_UNIQUE", quiz: quiz)
    )
  end
end
