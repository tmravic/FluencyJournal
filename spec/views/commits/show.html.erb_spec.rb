require 'rails_helper'

RSpec.describe "commits/show", type: :view do
  before(:each) do
    assign(:commit, Commit.create!(
      content: "MyText",
      entry: nil
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(//)
  end
end
