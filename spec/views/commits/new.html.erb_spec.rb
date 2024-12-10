require 'rails_helper'

RSpec.describe "commits/new", type: :view do
  before(:each) do
    assign(:commit, Commit.new(
      content: "MyText",
      entry: nil
    ))
  end

  it "renders new commit form" do
    render

    assert_select "form[action=?][method=?]", commits_path, "post" do

      assert_select "textarea[name=?]", "commit[content]"

      assert_select "input[name=?]", "commit[entry_id]"
    end
  end
end
