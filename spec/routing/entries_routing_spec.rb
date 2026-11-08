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
