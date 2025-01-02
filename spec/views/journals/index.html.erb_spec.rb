require 'rails_helper'

RSpec.describe "journals/index", type: :view do
  before(:each) do
    assign(:journals, [
      Journal.create!(
        title: "Title",
        content: "MyText",
        user: nil
      ),
      Journal.create!(
        title: "Title",
        content: "MyText",
        user: nil
      )
    ])
  end

  it "renders a list of journals" do
    render
    cell_selector = 'div>p'
    assert_select cell_selector, text: Regexp.new("Title".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new(nil.to_s), count: 2
  end
end
