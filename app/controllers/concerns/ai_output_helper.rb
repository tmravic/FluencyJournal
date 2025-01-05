module AiOutputHelper
  def find_ai_output_by_identifier(identifier)
    @ai_query.ai_outputs.find { |output| output.identifier == identifier }
  end
end