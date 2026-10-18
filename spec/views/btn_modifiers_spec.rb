require "rails_helper"

RSpec.describe "button modifiers", type: :view do
  def button_stylesheet
    Rails.root.join("app/assets/stylesheets/components/_btn.scss").read
  end

  def primary_modifier_block(scss)
    start = scss.index(/^\s*&--primary \{/)
    raise "missing &--primary" if start.nil?

    body_start = scss.index("{", start)
    depth = 0
    scss.each_char.with_index do |char, index|
      next if index < body_start

      depth += 1 if char == "{"
      depth -= 1 if char == "}"
      return scss[start..index] if depth.zero?
    end
    raise "unclosed &--primary"
  end

  it "does not chain short or manage-journal onto btn--primary" do
    scss = button_stylesheet
    primary = primary_modifier_block(scss)

    expect(primary).not_to include("&--short")
    expect(primary).not_to include("&--manage-journal")
    light = scss[/&--light \{.*?\n  \}/m]
    expect(light).not_to include("&--short")
    expect(scss).to include("  &--short {\n    padding: 0 var(--space-xxxs);\n  }")
    expect(scss).to include(
      "  &--manage-journal {\n    padding: var(--space-xxxs) var(--space-xxs);\n    font-size: var(--font-size-m);\n  }"
    )

    sources = Dir.glob(Rails.root.join("app/views/**/*.erb")) +
      Dir.glob(Rails.root.join("app/assets/stylesheets/**/*.scss"))
    chained = %w[btn--primary--short btn--primary--manage-journal btn--light--short]
    offenders = sources.filter_map do |path|
      text = File.read(path)
      hits = chained.select { |name| text.include?(name) }
      next if hits.empty?

      "#{path}: #{hits.join(', ')}"
    end

    expect(offenders).to eq([])
  end
end
