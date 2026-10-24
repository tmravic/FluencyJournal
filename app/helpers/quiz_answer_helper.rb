module QuizAnswerHelper
  # The match highlight compares every character of one text with every
  # character of the other, so its cost grows with the product of the two
  # lengths. Past this many characters in either text the answer is shown
  # as plain text instead.
  MAX_HIGHLIGHT_LENGTH = 2_000

  def highlighted_quiz_answer(original, user_response)
    if original.to_s.length > MAX_HIGHLIGHT_LENGTH || user_response.to_s.length > MAX_HIGHLIGHT_LENGTH
      return content_tag(:span, user_response.to_s)
    end

    segments = quiz_answer_match_segments(original, user_response)

    safe_join(segments.map { |segment| render_quiz_answer_segment(segment) })
  end

  def quiz_answer_entry(journal, quiz_entry)
    journal.entry_at(quiz_entry.line_number)
  end

  def quiz_answer_match_segments(original, user_response)
    original_text = original.to_s
    user_text = user_response.to_s
    return [ { match: false, text: user_text } ] if original_text.blank?

    original_chars = original_text.chars
    user_chars = user_text.chars
    matched_user_indices = longest_common_subsequence_user_indices(original_chars, user_chars)

    build_segments_from_indices(user_chars, matched_user_indices)
  end

  private

  def render_quiz_answer_segment(segment)
    css_class = segment[:match] ? "quiz-answer__match" : nil
    content_tag(:span, h(segment[:text]), class: css_class)
  end

  def build_segments_from_indices(user_chars, matched_user_indices)
    segments = []
    current_match = nil
    current_text = +""

    user_chars.each_with_index do |char, index|
      is_match = matched_user_indices.include?(index)

      if current_match.nil?
        current_match = is_match
        current_text = char
      elsif current_match == is_match
        current_text << char
      else
        segments << { match: current_match, text: current_text }
        current_match = is_match
        current_text = char.dup
      end
    end

    segments << { match: current_match, text: current_text } if current_text.present?
    segments
  end

  def longest_common_subsequence_user_indices(original_chars, user_chars)
    row_count = original_chars.length
    column_count = user_chars.length
    lcs_lengths = Array.new(row_count + 1) { Array.new(column_count + 1, 0) }

    (1..row_count).each do |row|
      (1..column_count).each do |column|
        if original_chars[row - 1] == user_chars[column - 1]
          lcs_lengths[row][column] = lcs_lengths[row - 1][column - 1] + 1
        else
          lcs_lengths[row][column] = [
            lcs_lengths[row - 1][column],
            lcs_lengths[row][column - 1]
          ].max
        end
      end
    end

    matched_user_indices = []
    row = row_count
    column = column_count

    while row.positive? && column.positive?
      if original_chars[row - 1] == user_chars[column - 1]
        matched_user_indices.unshift(column - 1)
        row -= 1
        column -= 1
      elsif lcs_lengths[row - 1][column] >= lcs_lengths[row][column - 1]
        row -= 1
      else
        column -= 1
      end
    end

    matched_user_indices.to_set
  end
end