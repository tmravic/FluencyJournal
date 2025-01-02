require 'rails_helper'

RSpec.describe "entries/index", type: :view do
  before(:each) do
    assign(:entries, [
      Entry.create!(
        content: "MyText",
        journal: nil
      ),
      Entry.create!(
        content: "MyText",
        journal: nil
      )
    ])
  end

  it "renders a list of entries" do
    render
    cell_selector = 'div>p'
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new(nil.to_s), count: 2
  end
end
