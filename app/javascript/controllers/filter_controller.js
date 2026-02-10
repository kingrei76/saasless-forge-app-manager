import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "search", "projectSelect"]

  connect() {
    this._timeout = null
    // Initialize project filter on page load
    if (this.hasProjectSelectTarget) {
      this.filterProjects()
    }
  }

  submit() {
    clearTimeout(this._timeout)
    this._timeout = setTimeout(() => {
      this.formTarget.requestSubmit()
    }, 300)
  }

  filterProjects(event) {
    if (!this.hasProjectSelectTarget) return

    const clientSelect = event?.target || this.element.querySelector('[name="client_id"]')
    const projectSelect = this.projectSelectTarget
    const selectedClientId = clientSelect?.value

    // Store current selection
    const currentProjectId = projectSelect.value

    // Show/hide options based on client
    Array.from(projectSelect.options).forEach(option => {
      if (option.value === "") {
        // Always show blank option
        option.hidden = false
      } else {
        const optionClientId = option.dataset.clientId
        option.hidden = selectedClientId && optionClientId !== selectedClientId
      }
    })

    // Clear selection if current project doesn't match selected client
    if (currentProjectId) {
      const currentOption = projectSelect.querySelector(`option[value="${currentProjectId}"]`)
      if (currentOption?.hidden) {
        projectSelect.value = ""
      }
    }
  }
}
