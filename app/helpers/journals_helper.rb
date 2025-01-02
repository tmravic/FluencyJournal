module JournalsHelper
  def display_change_list(change_list)
    tag.div class: "error-message" do
      change_list
    end
  end
end
