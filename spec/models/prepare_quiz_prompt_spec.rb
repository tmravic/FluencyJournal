require "rails_helper"

RSpec.describe PrepareQuizPrompt, type: :model do
  it "uses the same key prefix that its response format asks for" do
    group = Group.create!(name: "Prepare prefix #{SecureRandom.hex(4)}")
    user = User.create!(
      email_address: "prepare-prefix-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      original_language: "English",
      learning_language: "Japanese",
      group: group
    )
    journal = Journal.create!(title: "Prefix", user: user, group: group, last_interval: 1)
    journal.entries.create!(content: "一行目")
    journal.entries.create!(content: "二行目")
    prompt = described_class.new

    expect(prompt.change_keyword).to eq("line_")
    expect(prompt.response_format(user, journal, nil)).to include(%("line_1"), %("line_2"))

    body = { "line_1" => { "translation" => "a" }, "line_2" => { "translation" => "b" } }.to_json
    expect(AiQuery.new(raw_response: body).count_changes(prompt.change_keyword)).to eq(2)
  end
end
