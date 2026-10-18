require "spec_helper"

RSpec.describe "BEM element depth" do
  FORBIDDEN_CLASSES = %w[
    form__input__button_block
    card__change__title
    card__change__corrected
    card__change_content
  ].freeze

  it "does not leave nested element classes in views or stylesheets" do
    root = File.expand_path("..", __dir__)
    directories = [
      File.join(root, "app/views"),
      File.join(root, "app/assets/stylesheets")
    ]
    hits = []

    directories.each do |directory|
      Dir.glob(File.join(directory, "**", "*")).each do |path|
        next if File.directory?(path)

        relative = path.delete_prefix("#{root}/")
        next if relative.start_with?("app/assets/builds/")

        File.foreach(path).with_index(1) do |line, number|
          FORBIDDEN_CLASSES.each do |name|
            next unless line.include?(name)

            hits << "#{relative}:#{number}: #{name}"
          end
        end
      end
    end

    expect(hits).to eq([]), "Nested BEM class names remain:\n#{hits.join("\n")}"
  end
end
