require 'rails_helper'

RSpec.describe "entries/new", type: :view do
  before(:each) do
    assign(:entry, Entry.new(
      content: "MyText",
      journal: nil
    ))
  end

  it "renders new entry form" do
    render

    assert_select "form[action=?][method=?]", entries_path, "post" do

      assert_select "textarea[name=?]", "entry[content]"

      assert_select "input[name=?]", "entry[journal_id]"
    end
  end
end
