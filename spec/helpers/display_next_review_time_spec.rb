require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#display_next_review_time" do
    it "asks the browser whether the next study time is today" do
      reviews_on = Time.zone.local(2026, 10, 18, 9, 0, 0)
      journal = Journal.new(next_study_date: reviews_on)

      html = helper.display_next_review_time(journal)

      expect(html).to include('data-local="weekday-or-date"')
      expect(html).to include(%(datetime="#{reviews_on.utc.xmlschema}"))
      expect(html).not_to include(I18n.t("today"))
    end

    it "keeps the empty message when no date is set" do
      expect(helper.display_next_review_time(Note.new)).to eq(I18n.t("note.no_date_set"))
    end
  end
end
