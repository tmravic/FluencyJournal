require 'rails_helper'

RSpec.describe "journals/edit", type: :view do
  let(:journal) {
    Journal.create!(
      title: "MyString",
      content: "MyText",
      user: nil
    )
  }

  before(:each) do
    assign(:journal, journal)
  end

  it "renders the edit journal form" do
    render

    assert_select "form[action=?][method=?]", journal_path(journal), "post" do
      assert_select "input[name=?]", "journal[title]"
      assert_select "textarea[name=?]", "journal[content]"
      assert_select "input[name=?]", "journal[user_id]"
    end
  end
end
