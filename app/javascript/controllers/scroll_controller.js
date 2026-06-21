import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { target: String, scrollOnConnect: Boolean }

  connect() {
    if (this.scrollOnConnectValue) {
      requestAnimationFrame(() => this.scrollElementIntoView(this.scrollTarget()))
    }
  }

  scrollToTop() {
    window.scrollTo({ top: 0, behavior: "smooth" })
  }

  scrollToTarget() {
    const targetId = this.targetValue

    const scrollToFrame = () => {
      const element = document.getElementById(targetId)
      if (element) this.scrollElementIntoView(element)
    }

    const handleFrameEvent = (event) => {
      if (event.target?.id === targetId) {
        requestAnimationFrame(() => {
          requestAnimationFrame(scrollToFrame)
        })
        document.removeEventListener("turbo:frame-load", handleFrameEvent)
        document.removeEventListener("turbo:frame-render", handleFrameEvent)
      }
    }

    document.addEventListener("turbo:frame-load", handleFrameEvent)
    document.addEventListener("turbo:frame-render", handleFrameEvent)

    setTimeout(scrollToFrame, 1000)
  }

  scrollTarget() {
    return this.element.closest("turbo-frame") || this.element
  }

  scrollElementIntoView(element) {
    element.scrollIntoView({ behavior: "smooth", block: "start" })
  }
}