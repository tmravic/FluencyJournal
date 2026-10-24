import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="theme"
export default class extends Controller {
  static targets = ["icon"]
  static values = { lightLabel: String, darkLabel: String }

  connect() {
    this.updateIcon()
  }

  toggle() {
    const root = document.documentElement
    const current = root.dataset.theme || this.systemPreference()
    const next = current === "dark" ? "light" : "dark"

    root.dataset.theme = next
    localStorage.setItem("theme", next)
    this.updateIcon()
  }

  updateIcon() {
    if (!this.hasIconTarget) return

    const root = document.documentElement
    const current = root.dataset.theme || this.systemPreference()
    this.iconTarget.textContent = current === "dark" ? "☀️" : "🌙"
    this.element.setAttribute("aria-label", current === "dark" ? this.lightLabelValue : this.darkLabelValue)
  }

  systemPreference() {
    return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches
      ? "dark"
      : "light"
  }
}
