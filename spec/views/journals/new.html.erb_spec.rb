require 'rails_helper'

RSpec.describe "journals/new", type: :view do
  before(:each) do
    assign(:journal, Journal.new(
      title: "MyString",
      content: "MyText",
      user: nil
    ))
  end

  it "renders new journal form" do
    render

    assert_select "form[action=?][method=?]", journals_path, "post" do

      assert_select "input[name=?]", "journal[title]"

      assert_select "textarea[name=?]", "journal[content]"

      assert_select "input[name=?]", "journal[user_id]"
    end
  end
end
