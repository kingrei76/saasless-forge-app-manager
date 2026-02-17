import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    executionId: Number,
    pollInterval: { type: Number, default: 3000 },
    active: { type: Boolean, default: true }
  }

  static targets = ["status", "steps", "container"]

  connect() {
    if (this.activeValue) {
      this.poll()
    }
  }

  disconnect() {
    this.stopPolling()
  }

  poll() {
    this.timer = setInterval(() => this.refresh(), this.pollIntervalValue)
  }

  stopPolling() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }

  async refresh() {
    try {
      const response = await fetch(window.location.href, {
        headers: { "Accept": "text/html" }
      })

      if (response.ok) {
        const html = await response.text()
        const parser = new DOMParser()
        const doc = parser.parseFromString(html, "text/html")

        // Check if execution is still in progress
        const statusBadge = doc.querySelector("[data-execution-status]")
        if (statusBadge) {
          const status = statusBadge.dataset.executionStatus
          if (!["pending", "running", "awaiting_approval"].includes(status)) {
            this.stopPolling()
            // Full page refresh for final state
            window.location.reload()
          }
        }
      }
    } catch (e) {
      // Silently ignore polling errors
    }
  }
}
