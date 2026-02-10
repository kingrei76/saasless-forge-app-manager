import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { url: String, activeClass: String }

  connect() {
    // Set default active class if not specified
    if (!this.hasActiveClassValue) {
      this.activeClassValue = "tab-active"
    }
  }

  // Show a specific panel and update tab active states
  show(event) {
    event.preventDefault()
    const clickedTab = event.currentTarget
    const tabName = clickedTab.dataset.tab

    // Update tab active states
    this.tabTargets.forEach(tab => {
      if (tab.dataset.tab === tabName) {
        tab.classList.add(this.activeClassValue)
      } else {
        tab.classList.remove(this.activeClassValue)
      }
    })

    // Show/hide panels
    this.panelTargets.forEach(panel => {
      if (panel.dataset.panel === tabName) {
        panel.classList.remove("hidden")
      } else {
        panel.classList.add("hidden")
      }
    })
  }

  // Toggle via PATCH request (original functionality)
  async toggle(event) {
    event.preventDefault()
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    const response = await fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Accept": "text/vnd.turbo-stream.html"
      }
    })

    if (response.ok) {
      const html = await response.text()
      Turbo.renderStreamMessage(html)
    }
  }
}
