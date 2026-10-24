require "spec_helper"

RSpec.describe "inline styles" do
  TEMPLATES = %w[
    app/views/journals/_journal_content.html.erb
    app/views/journals/reading_mode.html.erb
    app/views/journals/compare.html.erb
    app/views/pages/home.html.erb
    app/views/notes/show.html.erb
  ].freeze

  it "does not leave style attributes on the listed templates" do
    root = File.expand_path("..", __dir__)
    hits = TEMPLATES.filter_map do |relative|
      text = File.read(File.join(root, relative))
      next unless text.include?("style=")

      relative
    end

    expect(hits).to eq([]), "Inline style attributes remain:\n#{hits.join("\n")}"
  end
end
