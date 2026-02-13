import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["detail", "icon"]
  static values = { open: { type: Boolean, default: false } }

  toggle(event) {
    // Don't toggle if clicking a link
    if (event.target.closest("a")) return

    this.openValue = !this.openValue
    this.detailTargets.forEach(row => {
      row.classList.toggle("hidden", !this.openValue)
    })
    if (this.hasIconTarget) {
      this.iconTarget.classList.toggle("fa-chevron-right", !this.openValue)
      this.iconTarget.classList.toggle("fa-chevron-down", this.openValue)
    }
  }
}
