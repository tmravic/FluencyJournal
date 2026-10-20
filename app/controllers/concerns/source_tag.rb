# frozen_string_literal: true

# Names of the two UI regions a followup or AI card can be rendered in.
# They prefix turbo frame / DOM ids, so views and controllers must agree.
module SourceTag
  AI_ASSISTANT = "ai_assistant"
  NOTES_BOX = "notes_box"
end
