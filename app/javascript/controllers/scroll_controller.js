import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="scroll"
export default class extends Controller {
  static values = { target: String }

  scrollToTop() {
    // Scroll to the top of the page
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  scrollToTarget() {
    const element = document.getElementById(this.targetValue);
    if (element) {
      element.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  }
}
