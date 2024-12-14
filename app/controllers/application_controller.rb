class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  private

  def current_group
    if Current.user&.group
      group_name = "Current group: #{Current.user&.group&.name}"
      @current_group ||= group_name if group_name && Current.user
    end
  end

  helper_method :current_group
end
