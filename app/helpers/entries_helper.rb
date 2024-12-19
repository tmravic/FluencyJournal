module EntriesHelper
  def display_change_list(change_list)
    puts "\n\n\n\nBIG TEST\n\n\n\n"
    tag.div class: "error-message" do
      change_list
    end
  end
end
