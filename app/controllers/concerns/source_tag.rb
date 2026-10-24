# frozen_string_literal: true

# Names of the two UI regions a followup or AI card can be rendered in.
# They prefix turbo frame / DOM ids, so views and controllers must agree.
module SourceTag
  AI_ASSISTANT = "ai_assistant"
  NOTES_BOX = "notes_box"
  ALL = [ AI_ASSISTANT, NOTES_BOX ].freeze

  # The tag from a request parameter, or nil when it is missing or not one of
  # the known regions. The value ends up in DOM ids and turbo frame names, so
  # anything else is dropped instead of being echoed back.
  def self.parse(value)
    value if ALL.include?(value)
  end
end
