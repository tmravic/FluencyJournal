# The shared responses for "mark as studied" and "update due date" on
# journals and notes.
module StudyActions
  extend ActiveSupport::Concern

  # How the "will return on" notice shows the next study date.
  STUDY_DATE_FORMAT = "%Y-%m-%d".freeze

  private

  # Marks +record+ studied. On success, runs the block (to set what the
  # turbo stream needs), then redirects to +redirect_path+ (HTML) or puts
  # the +notice_key+ notice in the flash (Turbo). Answers 422 otherwise.
  def respond_to_mark_studied(record, notice_key, redirect_path)
    return head(:unprocessable_entity) unless record.mark_studied

    yield if block_given?
    notice = studied_notice(record, notice_key)
    respond_to do |format|
      format.html { redirect_to redirect_path, status: :see_other, notice: notice }
      format.turbo_stream { flash.now[:notice] = notice }
    end
  end

  # Sets +record+'s next study date from params and renders the action's
  # turbo stream. Answers 422 when it does not save.
  def respond_to_due_date_update(record)
    return head(:unprocessable_entity) unless record.update(next_study_date: params.dig(:next_study_date))

    respond_to do |format|
      format.turbo_stream
    end
  end

  def studied_notice(record, notice_key)
    t(notice_key, date: helpers.local_date(record.next_study_date, format: STUDY_DATE_FORMAT)).html_safe
  end
end
