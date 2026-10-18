require "spec_helper"

RSpec.describe "naming scheme" do
  FORBIDDEN = [
    "notes_box_scroll",
    "note__change_due_date",
    "quiz_delete_buttons",
    "quiz_answer__match",
    "send_button_box",
    "navbar__notes_button",
    "followup__request_form",
    'id="send_button"',
    'id: "send_button"',
    "#send_button"
  ].freeze

  def project_root
    File.expand_path("..", __dir__)
  end

  def blocks_named(scss, selector)
    blocks = []
    offset = 0
    pattern = /^#{Regexp.escape(selector)}\s*\{/

    while (match = scss.match(pattern, offset))
      brace = match.end(0) - 1
      depth = 0
      finish = nil

      scss.each_char.with_index do |char, index|
        next if index < brace

        depth += 1 if char == "{"
        depth -= 1 if char == "}"
        if depth.zero?
          finish = index
          break
        end
      end

      break if finish.nil?

      blocks << scss[match.begin(0)..finish]
      offset = finish + 1
    end

    blocks
  end

  it "does not leave underscore class names or send_button ids" do
    directories = %w[app/views app/helpers app/assets/stylesheets app/javascript]
    hits = []

    directories.each do |relative_dir|
      directory = File.join(project_root, relative_dir)
      next unless File.directory?(directory)

      Dir.glob(File.join(directory, "**", "*")).each do |path|
        next if File.directory?(path)

        relative = path.delete_prefix("#{project_root}/")
        next if relative.start_with?("app/assets/builds/")

        File.foreach(path).with_index(1) do |line, number|
          FORBIDDEN.each do |name|
            next unless line.include?(name)

            hits << "#{relative}:#{number}: #{name}"
          end
        end
      end
    end

    expect(hits).to eq([]), "Old names remain:\n#{hits.join("\n")}"
  end

  it "does not nest a .header selector inside .note" do
    path = File.join(project_root, "app/assets/stylesheets/components/_note.scss")
    blocks = blocks_named(File.read(path), ".note")

    expect(blocks).not_to be_empty

    nested = blocks.flat_map.with_index do |block, index|
      block.each_line.with_index(1).filter_map do |line, number|
        next unless line.match?(/(^|[^A-Za-z0-9_-])\.header(?![A-Za-z0-9_-])/)

        ".note block #{index + 1}:#{number}: #{line.strip}"
      end
    end

    expect(nested).to eq([]), "Nested .header selectors remain in _note.scss:\n#{nested.join("\n")}"
  end
end
