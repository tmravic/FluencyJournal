require 'rails_helper'

RSpec.describe "entries/show", type: :view do
  before(:each) do
    assign(:entry, Entry.create!(
      content: "MyText",
      journal: nil
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(//)
  end
end
