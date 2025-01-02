import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="scroll"
export default class extends Controller {
  scrollToTop() {
    // Scroll to the top of the page
    window.scrollTo({ top: 0, behavior: "smooth" });
  }
}
