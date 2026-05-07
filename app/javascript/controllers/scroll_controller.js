import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="scroll"
export default class extends Controller {
  static values = { target: String }

  scrollToTop() {
    console.log("✅ scrollToTop was called");
    // Scroll to the top of the page
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  scrollToTarget() {
    console.log("✅ scrollToTarget was called with target:", this.targetValue)

    const targetId = this.targetValue

    // Wait for Turbo to finish inserting/updating the frame
    const onFrameRender = (event) => {
      if (event.target && event.target.id === targetId) {
        setTimeout(() => {
          event.target.scrollIntoView({ behavior: "smooth", block: "start" })
        }, 30)

        document.removeEventListener("turbo:frame-render", onFrameRender)
      }
    }

    document.addEventListener("turbo:frame-render", onFrameRender)

    // Safety fallback
    setTimeout(() => {
      const element = document.getElementById(targetId)
      if (element) {
        element.scrollIntoView({ behavior: "smooth", block: "start" })
      }
    }, 800)
  }
}
