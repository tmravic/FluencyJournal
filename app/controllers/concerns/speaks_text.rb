# Streams text as speech in the signed-in user's learning language.
# Controllers only say what to read aloud: speak_text(@journal.full_text).
module SpeaksText
  extend ActiveSupport::Concern

  private

  def speak_text(text)
    audio = XAiTtsService.new(api_key: @api_key, text: text, language: speech_language).call
    send_data audio, type: "audio/mpeg", disposition: "inline"
  rescue XAiTtsService::TtsError
    head :service_unavailable
  end

  # The TTS code for the learning language, or "auto" when there is none.
  def speech_language
    Prompt.language_code(Current.user.learning_language, default: "auto")
  end
end
