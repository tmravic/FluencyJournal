require "rails_helper"

# Entries only exist under a journal, and only for the actions the app uses.
RSpec.describe EntriesController, type: :routing do
  describe "routing" do
    it "routes the actions the app uses" do
      expect(get: "/journals/1/entries/new").to route_to("entries#new", journal_id: "1")
      expect(get: "/journals/1/entries/2/edit").to route_to("entries#edit", journal_id: "1", id: "2")
      expect(post: "/journals/1/entries").to route_to("entries#create", journal_id: "1")
      expect(put: "/journals/1/entries/2").to route_to("entries#update", journal_id: "1", id: "2")
      expect(patch: "/journals/1/entries/2").to route_to("entries#update", journal_id: "1", id: "2")
      expect(delete: "/journals/1/entries/2").to route_to("entries#destroy", journal_id: "1", id: "2")
      expect(get: "/journals/1/entries/2/speak").to route_to("entries#speak", journal_id: "1", id: "2")
      expect(get: "/journals/1/entries/2/cancel").to route_to("entries#cancel", journal_id: "1", id: "2")
    end

    it "has no index or show routes, and no top-level entries routes" do
      expect(get: "/journals/1/entries").not_to be_routable
      expect(get: "/journals/1/entries/2").not_to be_routable
      expect(get: "/entries").not_to be_routable
      expect(get: "/entries/1").not_to be_routable
      expect(post: "/entries").not_to be_routable
    end
  end
end

RSpec.describe QuizAnswersController, type: :routing do
  it "routes create, show, edit and retry only" do
    expect(post: "/journals/1/quizzes/2/quiz_answers").to route_to("quiz_answers#create", journal_id: "1", quiz_id: "2")
    expect(get: "/journals/1/quizzes/2/quiz_answers/3").to route_to("quiz_answers#show", journal_id: "1", quiz_id: "2", id: "3")
    expect(get: "/journals/1/quizzes/2/quiz_answers/3/edit").to route_to("quiz_answers#edit", journal_id: "1", quiz_id: "2", id: "3")
    expect(get: "/journals/1/quizzes/2/quiz_answers/3/retry").to route_to("quiz_answers#retry", journal_id: "1", quiz_id: "2", id: "3")
  end

  it "has no new, index, update or destroy routes" do
    # "new" now only matches show with id "new", which is a 404 (see
    # removed_scaffold_spec).
    expect(get: "/journals/1/quizzes/2/quiz_answers").not_to be_routable
    expect(patch: "/journals/1/quizzes/2/quiz_answers/3").not_to be_routable
    expect(delete: "/journals/1/quizzes/2/quiz_answers/3").not_to be_routable
  end
end
