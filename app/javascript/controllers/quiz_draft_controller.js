import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = { outputId: String }

  connect() {
    this.restore()
  }

  save() {
    if (!this.hasInputTarget) return

    sessionStorage.setItem(this.storageKey(), this.inputTarget.value)
  }

  restore() {
    if (!this.hasInputTarget) return

    const saved = sessionStorage.getItem(this.storageKey())
    if (saved !== null) {
      this.inputTarget.value = saved
    }
  }

  clear() {
    sessionStorage.removeItem(this.storageKey())
  }

  storageKey() {
    return `quiz-draft-${this.outputIdValue}`
  }
}