import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="template-prompt-select"
export default class extends Controller {
  static targets = ["textarea"]

  fill(event) {
    const select = event.currentTarget
    const value = select.value

    if (value) {
      this.textareaTarget.value = value
      // select.value = "" // reset dropdown
    }
  }
}
