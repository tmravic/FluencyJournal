import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.audio = null
    this.objectUrl = null
    this.loading = false
    this.abortController = null
  }

  disconnect() {
    this.stop()
    this.revokeObjectUrl()
  }

  async play() {
    if (this.loading) {
      this.stop()
      return
    }

    if (this.isPlaying()) {
      this.stop()
      return
    }

    if (this.audio) {
      this.audio.currentTime = 0
      await this.audio.play()
      return
    }

    await this.loadAndPlay()
  }

  isPlaying() {
    return this.audio && !this.audio.paused && !this.audio.ended
  }

  stop() {
    if (this.abortController) {
      this.abortController.abort()
      this.abortController = null
    }

    if (this.audio) {
      this.audio.pause()
      this.audio.currentTime = 0
    }

    this.loading = false
  }

  async loadAndPlay() {
    this.loading = true
    this.abortController = new AbortController()

    try {
      const response = await fetch(this.urlValue, { signal: this.abortController.signal })
      if (!response.ok) throw new Error("TTS request failed")

      const blob = await response.blob()
      this.revokeObjectUrl()
      this.objectUrl = URL.createObjectURL(blob)
      this.audio = new Audio(this.objectUrl)
      this.audio.addEventListener("ended", () => this.stop())

      await this.audio.play()
    } catch (error) {
      if (error.name !== "AbortError") {
        console.error("TTS playback failed:", error)
      }
      this.stop()
    } finally {
      this.loading = false
      this.abortController = null
    }
  }

  revokeObjectUrl() {
    if (this.objectUrl) {
      URL.revokeObjectURL(this.objectUrl)
      this.objectUrl = null
    }
  }
}