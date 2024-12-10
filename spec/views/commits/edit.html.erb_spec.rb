require 'rails_helper'

RSpec.describe "commits/edit", type: :view do
  let(:commit) {
    Commit.create!(
      content: "MyText",
      entry: nil
    )
  }

  before(:each) do
    assign(:commit, commit)
  end

  it "renders the edit commit form" do
    render

    assert_select "form[action=?][method=?]", commit_path(commit), "post" do

      assert_select "textarea[name=?]", "commit[content]"

      assert_select "input[name=?]", "commit[entry_id]"
    end
  end
end
